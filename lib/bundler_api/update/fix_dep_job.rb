require 'bundler_api'
require 'bundler_api/update/gem_db_helper'

class BundlerApi::FixDepJob
  @@gem_cache = {}

  def initialize(db, payload, counter = nil, mutex = nil)
    @db        = db
    @payload   = payload
    @mutex     = @mutex
    @counter   = counter
    @db_helper = BundlerApi::GemDBHelper.new(@db, @@gem_cache, @mutex)
  end

  def run
    if @db_helper.exists?(@payload)
      spec = nil
      begin
        spec = @payload.download_spec
      rescue BundlerApi::HTTPError => e
        puts e
      end

      begin
        deps = fix_deps(spec) if spec
      rescue StandardError => e
        puts "Error processing: #{spec.full_name}"
        puts e
      end
    end
  end

  private
  def fix_deps(spec)
    raise "Failed to load spec" unless spec

    deps_added = []

    @db.transaction do
      _, rubygem_id = @db_helper.find_or_insert_rubygem(spec)
      _, version_id = @db_helper.find_or_insert_version(spec, rubygem_id, @payload.platform, nil, true)
      deps_added    = @db_helper.insert_dependencies(spec, version_id)
    end

    if deps_added.any?
      print "Adding Missing Dep to #{spec.full_name}: #{deps_added.join(", ")}\n"
      @counter.increment if @counter
    end
  end
end
