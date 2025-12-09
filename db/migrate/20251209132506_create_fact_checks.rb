class CreateFactChecks < ActiveRecord::Migration[8.0]
  def change
    create_table :fact_checks do |t|
      t.references :listening_session, null: false, foreign_key: true
      t.string :claim, null: false
      t.integer :triggered_by_chunk_id
      t.string :verdict
      t.integer :confidence
      t.json :whats_true
      t.json :whats_wrong
      t.json :context_points
      t.json :sources
      t.string :status, default: "pending"
      t.datetime :processing_started_at
      t.datetime :completed_at
      t.text :error_message

      t.timestamps
    end

    add_index :fact_checks, [:listening_session_id, :created_at]
    add_index :fact_checks, :status
  end
end
