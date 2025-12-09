class CreateTranscriptChunks < ActiveRecord::Migration[8.0]
  def change
    create_table :transcript_chunks do |t|
      t.references :listening_session, null: false, foreign_key: true
      t.text :text, null: false
      t.boolean :is_final, default: false
      t.float :confidence
      t.float :start_time
      t.float :end_time
      t.json :words  # Word-level timestamps from Deepgram
      t.integer :speaker

      t.timestamps
    end

    add_index :transcript_chunks, [:listening_session_id, :start_time]
  end
end
