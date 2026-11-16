# frozen_string_literal: true

# Helpers for the `steep:untyped` task, kept in a module so they don't leak into the
# top-level namespace.
#
# Steep has no report of the methods without inline RBS annotations (`steep stats`
# skips inline sources), so this reads them with the inline parser of the rbs gem,
# the one Steep uses. It is an internal API of rbs 4.x: it may change.
module SteepUntyped
  module_function

  # Prints `file:line: Owner#method` for each method or attribute without annotations
  def report(file)
    require "rbs"
    require "prism"

    buffer = RBS::Buffer.new(name: file, content: File.read(file))
    result = RBS::InlineParser.parse(buffer, Prism.parse(buffer.content))
    result.declarations.sum { |decl| decl.respond_to?(:members) ? walk(decl, nil, file) : 0 }
  end

  # Returns how many members of the class or module, nested ones included, have no annotations
  def walk(decl, namespace, file)
    owner = [namespace, decl_name(decl)].compact.join("::")
    decl.members.sum do |member|
      if member.respond_to?(:members)
        walk(member, owner, file)
      else
        check(member, owner, file)
      end
    end
  end

  def check(member, owner, file)
    case member
    when RBS::AST::Ruby::Members::DefMember
      untyped(file, member, "#{owner}#{member.singleton? ? "." : "#"}#{member.name}") if member.method_type.empty?
    when RBS::AST::Ruby::Members::AttributeMember
      untyped(file, member, "#{owner} #{member.location.source.lines.first.strip}") unless member.type_annotation
    end.to_i
  end

  def decl_name(decl)
    (decl.respond_to?(:class_name) ? decl.class_name : decl.module_name).to_s.delete_prefix("::")
  end

  def untyped(file, member, label)
    puts "#{file}:#{member.location.start_line}: #{label}"
    1
  end
end

namespace :steep do
  desc "List the methods and attributes in lib/ without inline RBS type annotations"
  task :untyped do
    count = FileList["lib/**/*.rb"].sum { SteepUntyped.report(it) }
    puts "#{count} without annotations"
  end
end
