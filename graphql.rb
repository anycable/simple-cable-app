# frozen_string_literal: true

require "graphql"
require "graphql-anycable"

DATA = [
  {id: "1", title: "Lord of the Rings", read_count: 2},
  {id: "2", title: "Hobbit", read_count: 4},
  {id: "3", title: "For whom the bell talls", read_count: 0}
]

class BookType < GraphQL::Schema::Object
  field :id, ID, null: false
  field :title, String, null: false
  field :read_count, Integer, null: false
end

class ReadBookMutation < GraphQL::Schema::Mutation
  argument :id, ID, required: true

  field :book, BookType, null: false

  def resolve(id:)
    book = DATA.find { |el| el[:id] == id }
    book[:read_count] += 1

    ApplicationSchema.subscriptions.trigger("book_updated", {id: book[:id]}, book)
    {book: book}
  end
end

class BookUpdated < GraphQL::Schema::Subscription
  description "Event was changed"

  argument :id, ID, required: true

  field :book, BookType, null: false

  def subscribe(id:)
    book = DATA.find { |el| el[:id] == id }
    raise GraphQL::ExecutionError, "Not found" unless book

    {book: book}
  end

  def update(*)
    {book: object}
  end
end

class SubscriptionType < GraphQL::Schema::Object
  field :book_updated, subscription: BookUpdated
end


class ApplicationSchema < GraphQL::Schema
  use GraphQL::AnyCable, broadcast: true

  query(Class.new(GraphQL::Schema::Object) do
    def self.name
      "Query"
    end

    field :books, [BookType], null: false

    def books
      DATA
    end
  end)

  mutation(Class.new(GraphQL::Schema::Object) do
    def self.name
      "Mutation"
    end

    field :read_book, mutation: ReadBookMutation, null: false
  end)

  subscription(SubscriptionType)
end

class GraphqlChannel < ApplicationCable::Channel
  def execute(data)
    result =
      ApplicationSchema.execute(
        query: data["query"],
        context: context,
        variables: Hash(data["variables"]),
        operation_name: data["operationName"],
      )

    transmit({
      result: result.subscription? ? { data: nil } : result.to_h,
      more: result.subscription?,
    })
  end

  def unsubscribed
    channel_id = params.fetch("channelId")
    ApplicationSchema.subscriptions.delete_channel_subscriptions(channel_id)
  end

  private

  def context
    {
      channel: self
    }
  end
end

class GraphqlController < ApplicationController
  def execute
    variables = ensure_hash(params[:variables])
    query = params[:query]
    operation_name = params[:operationName]
    context = {}
    result = ApplicationSchema.execute(
      query,
      variables: variables,
      context: context,
      operation_name: operation_name
    )
    render json: result
  rescue => e
    render(
      json: {
        errors: [
          message: e.message
        ]
      }
    )
  end

  private

  # Handle form data, JSON body, or a blank value
  def ensure_hash(ambiguous_param)
    case ambiguous_param
    when String
      if ambiguous_param.present?
        ensure_hash(JSON.parse(ambiguous_param))
      else
        {}
      end
    when Hash
      ambiguous_param
    when ActionController::Parameters
      ambiguous_param.to_unsafe_hash
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{ambiguous_param}"
    end
  end
end
