require 'bundler_api'
require 'bundler_api/update/gem_db_helper'

class BundlerApi::Job
  attr_reader :payload
  @@gem_cache = {}

  def initialize(db, payload, mutex = Mutex.new, gem_count = nil)
    @db        = db
    @payload   = payload
    @mutex     = mutex
    @gem_count = gem_count
    @db_helper = BundlerApi::GemDBHelper.new(@db, @@gem_cache, @mutex)
  end

  def run
    unless @db_helper.exists?(@payload)
      @gem_count.increment if @gem_count
      spec = @payload.download_spec
      print "Adding: #{@payload.full_name}\n"
      @mutex.synchronize do
        insert_spec(spec)
      end
    end
  rescue BundlerApi::HTTPError => e
    puts "BundlerApi::Job#run gem=#{@payload.full_name.inspect} " +
         "message=#{e.message.inspect}"
  end

  def self.clear_cache
    @@gem_cache.clear
  end

  private
  def insert_spec(spec)
    raise "Failed to load spec" unless spec

    @db.transaction do
      rubygem_insert, rubygem_id = @db_helper.find_or_insert_rubygem(spec)
      version_insert, version_id = @db_helper.find_or_insert_version(spec, rubygem_id, @payload.platform, @payload.checksum, true)
      @db_helper.insert_dependencies(spec, version_id)
    end
  end
end
