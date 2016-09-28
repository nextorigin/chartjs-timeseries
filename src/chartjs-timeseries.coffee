extend = (root, objs...) ->
  root[key] = value for key, value of obj for obj in objs
  root


class TimeSeriesDatasetController extends Chart.controllers.line
  constructor: (context, options = {}) ->
    super
    {@limit, @direction} = options
    if !@limit and options.scales?.xAxes?.type is "time"
      @limit = (options.scales.xAxes.time.max - options.scales.xAxes.time.min)/1000

    @direction   or= "rtl"         # right-to-left
    super

  prepareForUpdate: ->
    # make a copy so we can delete used indices
    @_lastData = @getMeta().data[0..]

  updateElement: (point, index, reset) ->
    super
    return unless @_lastData
    oldposition = if @direction isnt "rtl" then index - 1 else index + 1
    if oldpoint = @_lastData[oldposition]
      point._view = oldpoint._view
      @_lastData[oldposition] = null


Chart.controllers.timeseries = TimeSeriesDatasetController
Chart.defaults.timeseries = Chart.defaults.line


{helpers} = Chart


class TimeSeries extends Chart.Controller
  constructor: (context, config) ->
    context = context[0] if context[0]?.getContext
    # Support a canvas domnode
    context = (context.getContext "2d") if context.getContext
    context.canvas.style.display or= "block"

    gridLines =
      drawScale: false
      display: true
    xTickCallback = (value) ->
      if value.toString().length > 0 then value else null
    yTickCallback = (value) ->
      if (typeof value is "number") then (Chart.Ticks.formatters.linear arguments...) else null
    ## BUGFIX we have to set scale types or they won't be merged
    defaultScaleType = "linear"
    xScale = config.options?.scales?.xAxes?[0]
    yScale = config.options?.scales?.yAxes?[0]
    if xScale and not xScale.type then xScale.type = defaultScaleType
    if yScale and not yScale.type then yScale.type = defaultScaleType

    defaults =
      scales:
        xAxes: [{gridLines, type: (xScale?.type or defaultScaleType), ticks: {autoSkip: false, maxRotation: 0, callback: xTickCallback}}]
        yAxes: [{gridLines, type: (yScale?.type or defaultScaleType), ticks: {callback: xTickCallback}}]

    config.type = "timeseries"
    config.options = helpers.configMerge defaults, config.options
    ## BUGFIX for when types are set or we get doubled axiis from Chart.defaults.global
    ## when Chart.core.controller calls helpers.configMerge
    # delete config.options?.scales?.xAxes?[0]?.type
    delete config.options?.scales?.yAxes?[0]?.type

    ## DEPRECATED after 2.3.0
    me     =
      controller: this
      ctx:        context
      canvas:     context.canvas
      config:     config

    # Figure out what the size of the chart will be.
    # If the canvas has a specified width and height, we use those else
    # we look to see if the canvas node has a CSS width and height.
    # If there is still no height, fill the parent container
    me.width  = context.canvas.width  or parseInt(helpers.getStyle(context.canvas, 'width'), 10)  or helpers.getMaximumWidth(context.canvas)
    me.height = context.canvas.height or parseInt(helpers.getStyle(context.canvas, 'height'), 10) or helpers.getMaximumHeight(context.canvas)

    me.aspectRatio = me.width / me.height

    if isNaN(me.aspectRatio) or isFinite(me.aspectRatio) is false
      # If the canvas has no size, try and figure out what the aspect ratio will be.
      # Some charts prefer square canvases (pie, radar, etc). If that is specified, use that
      # else use the canvas default ratio of 2
      me.aspectRatio = if config.aspectRatio? then config.aspectRatio else 2

    # Store the original style of the element so we can set it back
    me.originalCanvasStyleWidth  = context.canvas.style.width
    me.originalCanvasStyleHeight = context.canvas.style.height

    # High pixel density displays - multiply the size of the canvas height/width by the device pixel ratio, then scale.
    helpers.retinaScale me

    # Always bind this so that if the responsive state changes we still work
    helpers.addResizeListener context.canvas.parentNode, ->
      if me.controller?.config.options.responsive
        me.controller.resize()

    ## END DEPRECATED

    super me

  prepareForUpdate: ->
    for dataset, i in @data.datasets
      {controller} = @getDatasetMeta i
      controller?.prepareForUpdate()