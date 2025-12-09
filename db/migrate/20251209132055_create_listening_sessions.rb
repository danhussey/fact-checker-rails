class CreateListeningSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :listening_sessions do |t|
      t.string :session_token, null: false
      t.string :status, default: "idle"
      t.boolean :recording_enabled, default: false
      t.string :deepgram_connection_id

      t.timestamps
    end
    add_index :listening_sessions, :session_token, unique: true
    add_index :listening_sessions, :recording_enabled
  end
end
