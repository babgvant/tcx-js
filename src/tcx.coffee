###
Copyright 2015, Christopher Joakim <christopher.joakim@gmail.com>
###

expat = require('node-expat')
fs    = require('fs')
m26   = require("m26-js")

root = exports ? this

class Parser

  @VERSION:        '0.1.3'
  @FEET_PER_METER:  3.280839895013123
  @METERS_PER_MILE: 1609.344

  constructor: (opts={}) ->
    @options     = opts
    @parser      = new expat.Parser('UTF-8')
    @root_tag    = undefined
    @tag_stack   = []
    @paths       = []
    @end_reached = false
    @curr_tag    = undefined
    @curr_text   = ''
    @curr_tkpt   = undefined
    @tkpt0_time  = undefined
    @tkpt0_date  = undefined

    # @activity contains the parsed data:
    @activity = {}
    @activity.creator = {}
    @activity.author  = {}
    @activity.trackpoints = []

    @parser.on('startElement', (name, attrs) =>
      if @tag_stack.length == 0
        @root_tag = name
      @tag_stack.push(name)
      @curr_tag  = name
      @curr_text = ''
      p = this.curr_path()

      # this logic is for capturing/exploring the structure of the tcx/xml document
      @paths.push(p)
      for n,v of attrs
        @paths.push(p + '@' + n)

      switch p
        when "Activities|Activity|Lap|Track|Trackpoint"
          @curr_tkpt = {}
          @activity.trackpoints.push(@curr_tkpt)
    )

    @parser.on('endElement', (name) =>
      p = this.curr_path()
      switch p
        # Activity & Creator info
        when "Activities|Activity|Creator|Name"
          @activity.creator.name = @curr_text
        when "Activities|Activity|Creator|ProductID"
          @activity.creator.product_id = @curr_text
        when "Activities|Activity|Creator|UnitId"
          @activity.creator.unit_id = @curr_text
        when "Activities|Activity|Creator|Version|BuildMajor"
          @activity.creator.build_major = @curr_text
        when "Activities|Activity|Creator|Version|BuildMinor"
          @activity.creator.build_minor = @curr_text
        when "Activities|Activity|Creator|Version|VersionMajor"
          @activity.creator.version_major = @curr_text
        when "Activities|Activity|Creator|Version|VersionMinor"
          @activity.creator.version_minor = @curr_text
        when "Activities|Activity|Id"
          @activity.id = @curr_text

        # Trackpoints
        when "Activities|Activity|Lap|Track|Trackpoint|AltitudeMeters"
          @curr_tkpt.alt_meters = parseFloat(@curr_text)
        when "Activities|Activity|Lap|Track|Trackpoint|DistanceMeters"
          @curr_tkpt.dist_meters = parseFloat(@curr_text)
        when "Activities|Activity|Lap|Track|Trackpoint|Extensions|TPX|RunCadence"
          @curr_tkpt.run_cadence = parseInt(@curr_text)
        when "Activities|Activity|Lap|Track|Trackpoint|Cadence"
          @curr_tkpt.cadence = parseInt(@curr_text)
        when "Activities|Activity|Lap|Track|Trackpoint|HeartRateBpm|Value"
          @curr_tkpt.hr_bpm = parseInt(@curr_text)
        when "Activities|Activity|Lap|Track|Trackpoint|Position|LatitudeDegrees"
          @curr_tkpt.lat = parseFloat(@curr_text)
        when "Activities|Activity|Lap|Track|Trackpoint|Position|LongitudeDegrees"
          @curr_tkpt.lng = parseFloat(@curr_text)
        when "Activities|Activity|Lap|Track|Trackpoint|Time"
          @curr_tkpt.time = @curr_text
        when "Activities|Activity|Lap|TriggerMethod"
          x = 0
        when "Activities|Activity|Lap|Track|Trackpoint|Extensions|ns3:TPX|ns3:Watts"
          @curr_tkpt.watts = parseInt(@curr_text)
        when "Activities|Activity|Lap|Track|Trackpoint|Extensions|ns3:TPX|ns3:Speed"
          @curr_tkpt.speed = parseFloat(@curr_text)

        # Author info
        when "Author|Build|Version|BuildMajor"
          @activity.author.build_major = @curr_text
        when "Author|Build|Version|BuildMinor"
          @activity.author.build_minor = @curr_text
        when "Author|Build|Version|VersionMajor"
          @activity.author.version_major = @curr_text
        when "Author|Build|Version|VersionMinor"
          @activity.author.version_minor = @curr_text
        when "Author|LangID"
          @activity.author.lang = @curr_text
        when "Author|Name"
          @activity.author.name = @curr_text
        when "Author|PartNumber"
          @activity.author.part_number = @curr_text

      @tag_stack.pop()
      @curr_tag  = undefined
      @curr_text = ''
      if name == @root_tag
        @end_reached = true
        this.finish()
    )

    @parser.on('text', (text) =>
      @curr_text = @curr_text + text)

    @parser.on('error', (error) =>
      console.log('error ' + JSON.stringify(error)))

  parse_file: (filename) =>
    xml_str = fs.readFileSync(filename)
    @parser.parse(xml_str)

  parse_xml: (xml_str) =>
    @parser.parse(xml_str)

  curr_path: ->
    @tag_stack.slice(1).join('|')

  curr_full_path: ->
    @tag_stack.join('|')

  curr_depth: ->
    @tag_stack.length

  finish: ->
    # Augment the parsed Trackpoint data with calculated fields
    if @activity.trackpoints.length > 0
      @tkpt0_time = @activity.trackpoints[0].time
      @tkpt0_date = new Date(@tkpt0_time)

    for tkpt, idx in @activity.trackpoints
      tkpt.seq = idx + 1
      if @options.alt_feet == true
        altm  = Number(tkpt.alt_meters)
        tkpt.alt_feet = Parser.FEET_PER_METER * altm
      if @options.dist_miles == true
        distm = Number(tkpt.dist_meters)
        tkpt.dist_miles = distm / Parser.METERS_PER_MILE
      if @options.elapsed == true
        if @tkpt0_time
          dt  = new Date(tkpt.time)
          sec = (dt - @tkpt0_date) / 1000.0
          et  = new m26.M26ElapsedTime(sec)
          tkpt.elapsed_sec = sec
          tkpt.elapsed_hhmmss = et.as_hhmmss()

root.Parser = Parser
