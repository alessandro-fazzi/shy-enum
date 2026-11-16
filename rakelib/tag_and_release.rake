# frozen_string_literal: true

require "open3"

# Helpers for the `tag_and_release` task, kept in a module so they don't leak into the
# top-level namespace.
module TagRelease
  VERSION_FILE = "lib/shy/enum/version.rb"
  # Stable (1.2.3) or pre-release (1.2.3.pre1) versions.
  VERSION_REGEX = '\d+\.\d+\.\d+(?:\.pre\d+)?'
  VERSION_PATTERN = /VERSION = "(#{VERSION_REGEX})"/
  BUMPS = { "major" => 0, "minor" => 1, "patch" => 2 }.freeze

  module_function

  def git(*args)
    output, error, status = Open3.capture3("git", *args)
    abort "git #{args.join(" ")} failed: #{error.strip}" unless status.success?

    output.strip
  end

  def current_version
    File.read(VERSION_FILE)[VERSION_PATTERN, 1] or abort "VERSION not found in #{VERSION_FILE}"
  end

  # Tags look like v1.2.3 or v1.2.3.pre1; anything else is ignored.
  def tagged_versions
    git("tag", "--list", "v*").lines.filter_map do |tag|
      Gem::Version.new(tag.strip.delete_prefix("v")) if tag.strip.match?(/\Av#{VERSION_REGEX}\z/)
    end
  end

  def bumped(version, level)
    segments = Gem::Version.new(version).segments.first(BUMPS.size)
    index = BUMPS.fetch(level)
    segments[index] += 1
    segments[(index + 1)..] = [0] * (BUMPS.size - 1 - index)
    segments.join(".")
  end

  # Returns the new version chosen by the user.
  def ask_bump(version, latest)
    abort "Not an interactive terminal: cannot ask which version to bump." unless $stdin.tty?

    puts "Version #{version} is already tagged (latest tag: v#{latest})."
    label, target = choose(bump_options(version))
    BUMPS.key?(label) && confirm?("Make it a pre-release?") ? "#{target}.pre1" : target
  end

  def choose(options)
    print_menu(options)
    choice = $stdin.gets.to_s.strip
    abort "Aborted." unless choice.match?(/\A\d+\z/) && choice.to_i.between?(1, options.size)

    options[choice.to_i - 1]
  end

  def print_menu(options)
    options.each.with_index(1) { |(label, target), i| puts "  #{i}) #{label.ljust(7)} -> #{target}" }
    print "Which one? [1-#{options.size}, anything else to abort] "
  end

  # [label, resulting version] pairs. From a pre-release you can also go to the
  # next pre-release or to the stable version it leads to.
  def bump_options(version)
    current = Gem::Version.new(version)
    release = current.release.to_s
    options = BUMPS.keys.map { |level| [level, bumped(release, level)] }
    return options unless current.prerelease?

    [["pre", "#{release}.pre#{current.segments.last + 1}"], ["release", release], *options]
  end

  def confirm?(question)
    return false unless $stdin.tty?

    print "#{question} [y/N] "
    $stdin.gets.to_s.strip.casecmp?("y")
  end

  def run(*command)
    system(*command) or abort "Failed to run command: #{command.join(" ")}"
  end

  def write_version(new_version)
    path = VERSION_FILE
    File.write(path, File.read(path).sub(VERSION_PATTERN, %(VERSION = "#{new_version}")))
  end

  def commit_bump(new_version)
    write_version(new_version)
    # Gemfile.lock records the gem's own version: refresh it offline.
    run "bundle", "install", "--local", "--quiet"
    run "git", "add", VERSION_FILE, "Gemfile.lock"
    run "git", "commit", "--quiet", "-m", "version: bump to #{new_version}"
  end
end

desc "Tag the current version and push it; if it is already tagged, offer a bump (with commit) first"
task :tag_and_release do
  branch = TagRelease.git("branch", "--show-current")
  abort "Tag from main (current branch: #{branch})." unless branch == "main"
  dirty = !TagRelease.git("status", "--porcelain").empty?
  abort "Working tree not clean: commit or stash your changes first." if dirty

  # Tags created elsewhere must count too.
  TagRelease.run "git", "fetch", "--tags", "--quiet"

  version = Gem::Version.new(TagRelease.current_version)
  tagged = TagRelease.tagged_versions
  latest = tagged.max

  if latest && version < latest
    abort "Version #{version} is older than the latest tag v#{latest}: fix #{TagRelease::VERSION_FILE}."
  elsif tagged.include?(version)
    version = Gem::Version.new(TagRelease.ask_bump(version.to_s, latest))
    TagRelease.commit_bump(version.to_s)
  else
    puts "Version #{version} is not tagged yet (latest tag: #{latest ? "v#{latest}" : "none"})."
  end

  head = TagRelease.git("rev-parse", "--short", "HEAD")
  unless TagRelease.confirm?("Create tag v#{version} on #{head} and push #{branch} + tag to origin?")
    puts "Nothing pushed. Commits stay local; run `rake tag_and_release` again to resume."
    next
  end

  TagRelease.run "git", "tag", "-a", "v#{version}", "-m", "v#{version}"
  TagRelease.run "git", "push", "origin", branch, "v#{version}"
end
