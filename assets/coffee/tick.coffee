
# jQuery must have been initialized by now!
$ = jQuery


# Create the plugin within the jQuery context
$.fn.ticker = (options) ->

  # IE8 doesn't support String.trim() and lots of other stuff
  if( typeof String.prototype.trim is 'function' )

    for el in this
      el = $( el )

      if el.hasClass( 'tick-flip' )
        new Tick_Flip( $( el ), options )
      else if el.hasClass( 'tick-scroll' )
        new Tick_Scroll( $( el ), options )
      else
        new Tick( el, options )





###

  The acutal Ticker logic. The stored value is
  represented by a span/element per digit (and separator).

  Attributes

    options     object    all runtime options
    element     object    the element that is used for this ticker
    value       int       whatever value you pass in to the ticker
    separators  array     a list of the all separators that were found inbetween all digits
                          all digits are represented by an empty element
    running     boolean   indicates whether the ticker has been started
    increment   function  callback used to update @value on every tick

  Options

    incremental   mixed     can be either a fixed numeric value that gets added to the base value on each tick or
                            a function that gets called with the current value and must return the updated number
    delay (ms)    int       the time after which the target value is being increased
    separators    boolean   if true, all arbitrary characters inbetween digits are wrapped in seperated elements
                            if false, these characters are stripped out
    autostart     boolean   whether or not to start the ticker when instantiated
    fixeddecimals int       force plugin to show permanent decimal separator and minimum 'fixeddecimals' number of decimal digits
                            note: it is implemented for fixeddecimals<0 (no permanent decimal point) and fixeddecimals=2 only
                            (for case when fixeddecimals=2 then if value=2 output will be 2.00, 2.3 -> 2.30, 2.34->2.34 2.345 -> 2.345)

  Events

    onStart
    onTick
    onStop

###
class Tick

  constructor: (@element, options={}) ->

    @running = no

    @options =
      delay     : options.delay or 1000
      separators: if options.separators? then options.separators else false
      autostart : if options.autostart?  then options.autostart  else true
      fixeddecimals : if options.fixeddecimals?  then options.fixeddecimals  else -1
        
    @increment = @build_increment_callback( options.incremental )


    # extract the actual integer value without separators
    @value = Number( @element.html().replace( /[^\d.]/g, '' ))

    # retrieve all separators (digits are stored as empty elements for reference)
    @separators = @element.html().trim().split( /[\d]/i )

    @element.addClass( 'tick-active' )


    @start() if @options.autostart


  # create a callback for updating the ticker value based on the passed option
  build_increment_callback: (option) ->

    # check for valid function, inspired by http://stackoverflow.com/a/7356528
    if option? and {}.toString.call( option ) is '[object Function]'
      option

    else if typeof option is 'number'
      (val) -> val + option

    else
      (val) -> val + 1


  render: () ->

    digits      = String( @value ).split( '' )
    containers  = @element.children( ':not(.tick-separator)' )

    # add new containers for each digit that doesnt exist (if they do, just update them)
    if digits.length > containers.length
      for i in [0...(digits.length - containers.length)]
        # insert the separators at their designated position
        @build_separator( @separators[ i ]) if @options.separators and @separators[ i ]
        containers.push( @build_container( i ))
    else if digits.length < containers.length
      for i in [digits.length...containers.length]
        containers.last().remove()

    # insert/update the corresponding digit into each container
    @update_container( container, digits[ i ]) for container, i in containers



  ###
    These methods will create all visible elements and manipulate the output
  ###

  # override to change element type etc.
  build_container: (i) ->
    $( '<span></span>' ).appendTo( @element )


  # override to implement individual handling of separators
  build_separator: (content) ->
    $( "<span class='tick-separator'>#{content}</span>" ).appendTo( @element )


  # override to add animation logic etc.
  update_container: (container, digit) ->
    $( container ).html( digit )


  # dynamically reset the delay during runtime
  refresh_delay: (new_delay) ->
    clearTimeout( @timer );
    @options.delay = new_delay
    @set_timer()


  set_timer: () ->

    # setInterval() can cause problems in inactive tabs (see: http://goo.gl/pToBS)
    @timer = setTimeout( () =>
      @tick()
    , @options.delay ) if @running


  ###
    Events
  ###
  tick: () ->
    @value = @increment( @value ) #@options.incremental
    @render()
    @set_timer()


  ###
    Controls for the ticker
  ###
  start: () ->
    @element.empty()
    @render()

    @running = yes
    @set_timer()


  stop: () ->
    clearTimeout( @timer );
    @running = no





###
  CSS3 Transforms browser support:
  https://developer.mozilla.org/en/CSS/transform#Browser_compatibility
###

class Tick_Flip extends Tick

  build_container: (i) ->
    val = String( @value ).split( '' )[ i ]
    $( "<span class='tick-wrapper'>
        <span class='tick-old'>#{val}</span>
        <span class='tick-old-move'>#{val}</span>
        <span class='tick-new'></span>
        <span class='tick-new-move'>#{val}</span>
      </span>"
    )
    .appendTo( @element )


  # provides the flip animation based on simple callbacks
  flip: (target, digit, scale, duration, onComplete) ->

    target.css({ borderSpacing: 100 })

    target.stop(true, true).addClass( 'tick-moving' ).animate(
      { borderSpacing: 0 },
      { duration: duration, easing: 'easeInCubic', step: (now, fx) =>
        val = scale(now)
        target.css({
          '-webkit-transform': "scaleY(#{val})",
          '-moz-transform': "scaleY(#{val})",
          '-ms-transform': "scaleY(#{val})",
          '-o-transform': "scaleY(#{val})",
          'transform': "scaleY(#{val})"
        })

      complete: () =>
        target.html( digit )
            .css({
              borderSpacing: '',
              '-webkit-transform': '',
              '-moz-transform': '',
              '-ms-transform': '',
              '-o-transform': '',
              'transform': ''
            })
            .removeClass( 'tick-moving' )

        onComplete()
      })


  # calculate the step value for the respective half of the flip card
  upper: (now) -> now / 100
  lower: (now) => 1 - @upper( now )


  update_container: (container, digit) ->

    # reference build_container() for elements/indices
    parts = $( container ).children()

    if( @running and parts.eq( 2 ).html() != digit )

      @flip( parts.eq( 1 ), digit, @upper, @options.delay / 4, () ->
        )

      @flip( parts.eq( 3 ).html( digit ), digit, @lower, @options.delay / 3, () ->
        parts.eq( 0 ).html( digit ))


    parts.eq( 2 ).html( digit )


#polyfill Number.isInteger because IE11 doesn't support it
Number.isInteger = Number.isInteger or (value) ->
  typeof value == 'number' and isFinite(value) and Math.floor(value) == value

class Tick_Scroll extends Tick

  build_container: (i) ->
    $( '<span class="tick-separator-placeholder">.</span><span class="tick-wheel"><span>0</span><span>1</span><span>2</span><span>3</span><span>4</span><span>5</span><span>6</span><span>7</span><span>8</span><span>9</span></span>' ).appendTo( @element )



  render: () ->
    if !@value?
      return

    if @options.fixeddecimals > 0
      @value = String( @value )
      n = @value.lastIndexOf('.')
      if n < 0
        @value += '.00'
      else if @value.length - n == 2 #implement for case when separator should be in options.fixeddecimals place
        @value += '0'

    digits      = String( @value ).split( '' )
    containers  = @element.children( ':not(.tick-separator-placeholder)' )

    _nondigits_count = 0
    separator_position = -1
    for i in [0...digits.length]
      if !Number.isInteger(digits[i] / 1)
        ++_nondigits_count
        #todo only one separator is supported currently
        separator_position = digits.length - i - 1
    


    # add new containers for each digit that doesnt exist (if they do, just update them)
    if digits.length > containers.length + _nondigits_count
      for i in [0...(digits.length - _nondigits_count - containers.length)]
        # insert the real digit at their designated position
          containers.push( @build_container( i ))
    else if digits.length < containers.length + _nondigits_count
      for i in [(digits.length - _nondigits_count)...containers.length]
        @element.children('.tick-separator-placeholder').last().remove();
        @element.children('.tick-wheel').last().remove();

    @update_separator_position separator_position, @element.parent().find('.zero-mask').children('.tick-separator-scroll')


    # insert/update the corresponding digit into each container
    i = 0
    for k in [0...(containers.length+_nondigits_count)]
      if Number.isInteger(digits[k] / 1)
        @update_container( containers[i], digits[ k ])
        ++i

  update_container: (container, digit) ->
    elementHeight = $( container ).children().first().outerHeight( true )
    if( @running )
      $( container ).animate({ top: digit * -elementHeight }, @options.delay )
    else
      $( container ).css({ top: digit * -elementHeight })

  update_separator_position: (position, separators) ->
      for i in [0...separators.length]
        # deactivate previous separator
        $(separators[i]).removeClass("tick-separator-active");
      # activate required separator
      $(separators[separators.length-position]).addClass("tick-separator-active");

  #DO NOT USE THIS in PRODUCTION, IT IS JUST for testing purposes
  ticktest: (value, shouldempty) ->
      if(shouldempty)
        @element.empty();
      @value = value;
      @running = true;
      @render();

