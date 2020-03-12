require_relative 'lib/imperituroard/version'

Gem::Specification.new do |spec|
  spec.name          = "imperituroard"
  spec.version       = Imperituroard::VERSION
  spec.authors       = ["Dzmitry Buynovskiy"]
  spec.email         = ["imperituro.ard@gmail.com"]

  spec.summary       = %q{imperituroard gem}
  spec.description   = %q{Gem from imperituroard for different actions}
  spec.homepage      = "https://rubygems.org/"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["allowed_push_host"] = "https://rubygems.org/"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/imperituroard/imperituroard"
  spec.metadata["changelog_uri"] = "https://rubygems.org/"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "net-ssh", '~> 4.0.0'
  spec.add_development_dependency "mysql2"
  spec.add_development_dependency "savon"
  spec.add_development_dependency "json"
  spec.add_development_dependency "uri"

end