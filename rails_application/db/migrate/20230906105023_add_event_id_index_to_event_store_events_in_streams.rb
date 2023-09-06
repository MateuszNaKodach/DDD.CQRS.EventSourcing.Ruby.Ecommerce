# frozen_string_literal: true

class AddEventIdIndexToEventStoreEventsInStreams < ActiveRecord::Migration[7.0]
  def change
    return if index_exists?(:event_store_events_in_streams, :event_id)

    add_index :event_store_events_in_streams, [:event_id]
  end
end
