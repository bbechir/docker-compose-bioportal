#local IP address lookup. This hack doesn't make connection to external hosts
require 'socket'
  def local_ip
    orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true  # turn off reverse DNS resolution temporarily

    UDPSocket.open do |s|
      s.connect '8.8.8.8', 1 #google
      s.addr.last
    end
  ensure
    Socket.do_not_reverse_lookup = orig
  end

$LOCAL_IP = local_ip
$SITE_URL = "bioportal.lirmm.fr"

begin
  LinkedData.config do |config|
    config.repository_folder  = "/srv/ncbo/repository"
    config.goo_host           = "localhost"
    config.goo_port           = 8081
    config.search_server_url  = "http://localhost:8082/solr/core1"
    config.rest_url_prefix    = "http://data.#{$SITE_URL}/"
    config.replace_url_prefix = true
    config.id_url_prefix      = "http://data.bioontology.org/"
    config.enable_security    = false # set on false for CRON
    config.apikey             = "24e0e77e-54e0-11e0-9d7b-005056aa3316"
    config.ui_host            = "#{$SITE_URL}"
    config.sparql_endpoint_url = "http://sparql.#{$SITE_URL}/test"
    config.enable_monitoring  = false
    config.cube_host          = "localhost"
    config.enable_slices      = true
    config.enable_resource_index  = false

    # Used to define other bioportal that can be mapped to
    # Example to map to ncbo bioportal : {"ncbo" => {"api" => "http://data.bioontology.org", "ui" => "http://bioportal.bioontology.org", "apikey" => ""}
    # Then create the mapping using the following class in JSON : "http://purl.bioontology.org/ontology/MESH/C585345": "ncbo:MESH"
    # Where "ncbo" is the namespace used as key in the interportal_hash
    config.interportal_hash   = {"ncbo" => {"api" => "http://data.bioontology.org", "ui" => "http://bioportal.bioontology.org", "apikey" => "4a5011ea-75fa-4be6-8e89-f45c8c84844e"},
                                 "agroportal" => {"api" => "http://data.agroportal.lirmm.fr", "ui" => "http://agroportal.lirmm.fr", "apikey" => "1cfae05f-9e67-486f-820b-b393dec5764b"}}

    # Caches
    config.http_redis_host    = "localhost"
    config.http_redis_port    = 6380
    config.enable_http_cache  = true
    config.goo_redis_host     = "localhost"
    config.goo_redis_port     = 6382

    Goo.use_cache             = true

    # Email notifications
    config.enable_notifications   = true
    config.email_sender           = "notifications@bioportal.lirmm.fr" # Default sender for emails
    config.email_override         = "override@example.org" # all email gets sent here. Disable with email_override_disable.
    config.email_disable_override = true
    config.smtp_host              = "smtp.lirmm.fr"
    config.smtp_port              = 25
    config.smtp_auth_type         = :none # :none, :plain, :login, :cram_md5
    config.smtp_domain            = "lirmm.fr"
    # Emails of the instance administrators to get mail notifications when new user or new ontology
    config.admin_emails           = ["jonquet@lirmm.fr", "vincent.emonet@lirmm.fr"]

    # PURL server config parameters
    config.enable_purl            = false
    config.purl_host              = "purl.example.org"
    config.purl_port              = 80
    config.purl_username          = "admin"
    config.purl_password          = "password"
    config.purl_maintainers       = "admin"
    config.purl_target_url_prefix = "http://example.org"

    # Ontology Google Analytics Redis
    # disabled
    config.ontology_analytics_redis_host = "localhost"
    config.enable_ontology_analytics = true
    config.ontology_analytics_redis_port = 6379
end
rescue NameError
  puts "(CNFG) >> LinkedData not available, cannot load config"
end

begin
  Annotator.config do |config|
    config.mgrep_dictionary_file   = "/srv/mgrep/dictionary/dictionary.txt"
    config.stop_words_default_file = "/srv/ncbo/ncbo_cron/config/french_stop_words.txt"
    config.mgrep_host              = "localhost"
    config.mgrep_port              = 55555
    config.mgrep_alt_host          = "localhost"
    config.mgrep_alt_port          = 55555
    config.annotator_redis_host    = "localhost"
    config.annotator_redis_port    = 6379
    config.annotator_redis_prefix  = "c1:"
    config.annotator_redis_alt_prefix  = "c2:"
end
rescue NameError
  puts "(CNFG) >> Annotator not available, cannot load config"
end

begin
  OntologyRecommender.config do |config|
end
rescue NameError
  puts "(CNFG) >> OntologyRecommender not available, cannot load config"
end

begin
  LinkedData::OntologiesAPI.config do |config|
    config.enable_unicorn_workerkiller = true
    config.enable_throttling           = false
    config.enable_monitoring           = false
    config.cube_host                   = "localhost"
    config.http_redis_host             = "localhost"
    config.http_redis_port             = 6380
    config.ontology_rank               = ""
end
rescue NameError
	  puts "(CNFG) >> OntologiesAPI not available, cannot load config"
end

begin
  NcboCron.config do |config|
    config.redis_host                = Annotator.settings.annotator_redis_host
    config.redis_port                = Annotator.settings.annotator_redis_port
    config.daemonize                 = false
    config.user                      = root
    # Schedules: run every 4 hours, starting at 00:30
    config.cron_schedule							= "30 */4 * * *"
    # Pull schedule: run daily at 6 a.m. (18:00)
    config.pull_schedule							= "00 18 * * *"
    # Delete class graphs of archive submissions: run twice per week on tuesday and friday at 10 a.m. (22:00)
    config.cron_flush								= "00 22 * * 2,5"
    # Remove graphs from deleted ontologies when flushing class graphs
    config.remove_zombie_graphs                     = true
    # Warmup long time running queries: run every 3 hours (beginning at 00:00)
    config.cron_warmq								= "00 */3 * * *"
    # Create mapping counts schedule: run twice per week on Wednesday and Saturday at 12:30AM
    config.cron_mapping_counts						= "30 0 * * 3,6"
    
    config.enable_ontologies_report  = true
    # Ontologies report generation schedule: run daily at 1:30 a.m.
    config.cron_ontologies_report					= "30 1 * * *"
    # Ontologies Report file location
    config.ontology_report_path 					= "/srv/ncbo/reports/ontologies_report.json"
    
	# Ontology analytics refresh schedule: run daily at 4:30 a.m.
    config.cron_ontology_analytics ||= "30 4 * * *"
    config.enable_ontology_analytics = true
    config.analytics_service_account_email_address 	= "account-1@bioportal-1131.iam.gserviceaccount.com"
    config.analytics_path_to_key_file              	= "/srv/bioportal-f52e2cbedc59.p12" # you have to get this file from Google
    config.analytics_profile_id                    	= "ga:111836024" # replace with your ga view id
    config.analytics_app_name                      	= "bioportal"
    config.analytics_app_version                   	= "1.0.0"
    config.analytics_start_date                    	= "2015-11-16"
    config.analytics_filter_str                    	= ""
  end
rescue NameError
  #binding.pry
  puts "(CNFG) >> NcboCron not available, cannot load config"
end

