# frozen_string_literal: true

require 'fileutils'

module Architext
  class Settings
    attr_reader :config_path

    def initialize(config_path: default_config_path)
      @config_path = config_path
    end

    def default_vault
      return nil unless File.file?(@config_path)

      value = File.read(@config_path).strip
      value.empty? ? nil : value
    rescue StandardError
      nil
    end

    def default_vault=(vault)
      value = vault.to_s.strip
      raise ArgumentError, 'default vault cannot be blank' if value.empty?

      FileUtils.mkdir_p(File.dirname(@config_path))
      File.write(@config_path, "#{value}\n")
    end

    def clear_default_vault
      File.delete(@config_path) if File.file?(@config_path)
    end

    private

    def default_config_path
      File.join(Dir.home, '.config', 'architext', 'default_vault')
    end
  end
end
