Gem::Specification.new do |spec|
  spec.name          = "lita-slack-standup"
  spec.version       = "1.0.1"
  spec.authors       = ["Sybil Deboin"]
  spec.email         = ["sybil.deboin@gmail.com"]
  spec.description   = "Standup feature for slack"
  spec.summary       = "A lita gem to enable standups on slack"
  spec.homepage      = "https://github.com/blackbirdco/lita-slack-standup"
  spec.license       = "GNU v3.0"
  spec.metadata      = { "lita_plugin_type" => "handler" }

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "lita", ">= 4.7"
  spec.add_runtime_dependency "lita-slack"
  spec.add_runtime_dependency "slack-ruby-client"
  spec.add_runtime_dependency "redis-objects"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", ">= 3.0.0"
  spec.add_development_dependency "webmock"
end
