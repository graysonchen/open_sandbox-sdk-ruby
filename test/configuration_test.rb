# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def teardown
    # Reset to defaults after each test
    OpenSandbox.instance_variable_set(:@configuration, nil)
    OpenSandbox.reset_client!
  end

  def test_default_base_url_from_env
    ENV["SANDBOX_DOMAIN"] = "http://custom:9999"
    cfg = OpenSandbox::Configuration.new
    assert_equal "http://custom:9999", cfg.base_url
  ensure
    ENV.delete("SANDBOX_DOMAIN")
  end

  def test_configure_block_updates_config
    OpenSandbox.configure do |c|
      c.base_url = "http://test:1234"
      c.api_key  = "sk-test"
      c.timeout  = 60
    end
    assert_equal "http://test:1234", OpenSandbox.configuration.base_url
    assert_equal "sk-test",          OpenSandbox.configuration.api_key
    assert_equal 60,                 OpenSandbox.configuration.timeout
  end

  def test_configure_resets_singleton_client
    client1 = OpenSandbox.client
    OpenSandbox.configure { |c| c.base_url = "http://other:8000" }
    client2 = OpenSandbox.client
    refute_same client1, client2
  end

  def test_logger_defaults_to_silent
    cfg = OpenSandbox::Configuration.new
    assert_instance_of Logger, cfg.logger
  end
end
