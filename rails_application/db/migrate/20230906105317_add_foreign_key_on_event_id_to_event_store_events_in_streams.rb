# frozen_string_literal: true

class AddForeignKeyOnEventIdToEventStoreEventsInStreams < ActiveRecord::Migration[7.0]
  def change
    add_foreign_key :event_store_events_in_streams, :event_store_events, column: :event_id, primary_key: :event_id, if_not_exists: true, validate: false
  end
end
