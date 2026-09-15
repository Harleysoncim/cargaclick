class AddExpiresAtToCotacoes < ActiveRecord::Migration[7.0]
  def change
    add_column :cotacoes, :expires_at, :datetime, null: true

    # Set default expiry of 30 minutes for all existing cotacoes created more than 30 minutes ago
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE cotacoes
          SET expires_at = created_at + INTERVAL '30 minutes'
          WHERE expires_at IS NULL
            AND created_at < NOW() - INTERVAL '30 minutes'
        SQL
      end
    end

    add_index :cotacoes, :expires_at
  end
end
