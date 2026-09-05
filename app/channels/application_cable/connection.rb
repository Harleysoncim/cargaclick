module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = verified_user
    end

    private

    def verified_user
      env["warden"]&.user(:admin_user) ||
        env["warden"]&.user(:cliente) ||
        env["warden"]&.user(:transportador) ||
        reject_unauthorized_connection
    end
  end
end
