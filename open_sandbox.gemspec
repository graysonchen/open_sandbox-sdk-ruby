# frozen_string_literal: true

require_relative "lib/open_sandbox/version"

Gem::Specification.new do |spec|
  spec.name    = "open_sandbox"
  spec.version = OpenSandbox::VERSION
  spec.authors = ["Grayson Chen"]
  spec.email   = ["cgg5207@sina.com"]

  spec.summary     = "Ruby SDK for the open-sandbox.ai API"
  spec.description = "A lightweight, idiomatic Ruby client for managing isolated container sandboxes via the open-sandbox.ai REST API. Supports sandbox lifecycle (create, pause, resume, delete), resource pools, diagnostics, HTTP proxying, and polling helpers."
  spec.homepage    = "https://github.com/graysonchen/open_sandbox-sdk-ruby"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata = {
    "homepage_uri"      => spec.homepage,
    "source_code_uri"   => "https://github.com/graysonchen/open_sandbox-sdk-ruby",
    "changelog_uri"     => "https://github.com/graysonchen/open_sandbox-sdk-ruby/blob/main/CHANGELOG.md",
    "bug_tracker_uri"   => "https://github.com/graysonchen/open_sandbox-sdk-ruby/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir[
    "lib/**/*.rb",
    "sig/**/*.rbs",
    "CHANGELOG.md",
    "LICENSE",
    "README.md"
  ]

  spec.require_paths = ["lib"]

  spec.add_dependency "httparty", ">= 0.21", "< 1"
end
