# frozen_string_literal: true

require "rails/generators"

module OpenSandbox
  module Generators
    # Generates config/initializers/open_sandbox.rb in the host Rails app.
    #
    # Usage:
    #   rails generate open_sandbox:install
    #
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates an OpenSandbox initializer in config/initializers/"

      def copy_initializer
        template "initializer.rb", "config/initializers/open_sandbox.rb"
      end
    end
  end
end
