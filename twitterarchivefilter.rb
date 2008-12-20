#!/usr/bin/env ruby -Ku
$KCODE="u"
# ====================================================================================
# Twitter Archive Filter
#
# 1.0.5 => 2008/05/08 by Seasons
# 1.0.4 => 2008/05/07 by Seasons
# 1.0.3 => 2008/05/03 by Seasons
# 1.0.2 => 2008/04/24 by Seasons
# 1.0.1 => 2008/04/21 by Seasons
# 1.0.0 => 2008/04/21 by Seasons
#
# Special Thanks!!
# Twitter : @gan2
#
# mailto:keisuke@hata.biz
# Twitter:Seasons
# ====================================================================================

require 'rubygems'
require 'scrapi'
require 'net/http'
require 'kconv'
require 'optparse'
require '.twitter_user_pass' #=> Twitter Username & Password

$stdout.sync = true

alias :_puts :puts
def puts( *args )
  _puts *args
  $stdout.flush
end

#-------------------------------------------------------------------------------------
# System Config
#-------------------------------------------------------------------------------------
BASEPATH = '/account/archive' #=> default page archive to get
#BASEPATH = '/home' #=> if you want a recent timeline
#-------------------------------------------------------------------------------------

# *=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
#
# Twitter Archive Filter
#
# *=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=
class TwitterArchiveFilter

  def initialize ( keyword , pagenum , username , usebrace )
    @items = []
    @username = username
    @usebrace = usebrace
    @pagenum = pagenum
    @http = Net::HTTP.new( 'twitter.com', 80 )
    @keyword_reg = usebrace ? /\[#{keyword}\]/i : /#{keyword}/i
  end

  # ===========================================================================
  # @brief : filter
  #
  # @param : none
  #
  # @ret : none
  # ===========================================================================
  def filter()
    getArchives()
  end

  # ===========================================================================
  # @brief : dump Twitter archives
  #
  # @param : output filename
  # @param : verbose
  #
  # @ret : none
  #
  # @note
  # utf8 encoding
  # ===========================================================================
  def dump( outputfilename , verbose )
    open( outputfilename , "w" ) do |f|
      @items.each do |msg,time|
        f.puts "#{time} : #{msg}" #=> message : time
        puts "#{time} : #{msg}".tosjis if verbose
      end
    end

  end

  # ===========================================================================
  # @brief : add archive items
  #
  # @param : archive item
  #
  # @ret : none
  # ===========================================================================
  def addItems( items )
    return unless items
    @items.concat items[:messages].zip( items[:times] )
  end

  # ===========================================================================
  # @brief : get archives
  #
  # @param : none
  #
  # @ret : none
  #
  # @note
  # ===========================================================================
  def getArchives()

    nextlink = @username ? "/#{@username}" : BASEPATH
    count = 0
    while( nextlink )
      break if count == @pagenum
      html = getPageArchive( nextlink )
      items = getItems( html )
      next unless items or items[:messages] or items[:times] #=> Retry if failed get items...
      addItems( items )
      nextlink = getNextLink( html )
      puts "GetPage [#{count += 1}]"
    end
    #keyword filter
    @items = @items.reject{|msg,time| msg !~ @keyword_reg } if @keyword_reg

  end

  # ===========================================================================
  # @brief : get Messages & Times
  #
  # @param : html body
  #
  # @ret : Twitter message & time
  # ret = getItems()
  # ret["messages"] => Messagesage
  # ret["times"] => Times
  # ===========================================================================
  def getItems( html )
    items = Scraper.define do
      process 'td.content>span.entry_content' , "messages[]" => :text
      process 'td.content>span.entry-content' , "messages[]" => :text
      process 'td.content>span.meta>a>abbr.published' , "times[]" => "@title"
      result :messages , :times
    end.scrape( html , :parser_options => {:char_encoding=>'utf8'} )
    items

  end

  # ===========================================================================
  # @brief : get next LinkPage
  #
  # @param : html body
  #
  # @ret : Next url
  # ===========================================================================
  def getNextLink( html )
    links = Scraper.define do
      process 'div.pagination>a' , :url => "@href" , :kind => :text
      result :url , :kind
    end.scrape( html , :parser_options => {:char_encoding=>'utf8'} )
    links[:kind] =~ /Older/ ? links[:url] : nil

  end

  # ===========================================================================
  # @brief : get archives
  #
  # @param : get page(/account/archive)
  #
  # @ret : result(html body)
  # html = getPageArchive()
  # ===========================================================================
  def getPageArchive( page )
    html = ""
    req = Net::HTTP::Get.new( page )
    req.basic_auth( USERNAME , PASSWORD ) unless @username
    rs = @http.request( req )
    return html unless rs
    html= rs.body

  end

  private :getArchives , :getItems , :getNextLink , :getPageArchive , :addItems

end

if $0 == __FILE__

  pagenum     = -1
  keyword     = nil
  username    = nil
  verbose     = false
  usebrace    = false
  logfilename = 'archive.log'

  opt        = OptionParser.new
  opt.banner = "\nUsage: #{$0} [-k KEYWORD] [-s STOPOLDERPAGE]\n    e.g.) #{$0} -kvim -p10 -b -larchive.log\n    e.g.) #{$0} -kvim -p10 -uSeasons"
  opt.on( '-k' , '--keyword=KEYWORD'      , String  ) { |key| keyword = key }
  opt.on( '-p' , '--pagenum=PAGENUM'      , Integer ) { |page|  pagenum = page if page > 0 }
  opt.on( '-l' , '--logfile=LOGFILE'      , String  ) { |filename| logfilename = filename }
  opt.on( '-u' , '--user=TWITTERUSERNAME' , String  ) { |user| username = user }
  opt.on( '-b' , '--breace' ) { |brace_flg| usebrace = brace_flg }
  opt.on( '-v' , '--verbose' ) { |verbose_flg| verbose = verbose_flg }

  def opt.error( msg = nil )
    abort msg if msg
    abort help()
  end
  begin
    opt.parse!
  rescue OptionParser::ParseError => err
    opt.error err.message
  end

  puts "Keyword => " + ( keyword ? usebrace ? "[#{keyword}]" : keyword : "*.*" )
  puts "PageNum => #{pagenum}"
  puts "LogFile => #{logfilename}"
  tw = TwitterArchiveFilter.new( keyword , pagenum , username , usebrace )
  tw.filter()
  tw.dump( logfilename,verbose )
  puts "Succeed Twitter Archive!! > #{logfilename}"

end

