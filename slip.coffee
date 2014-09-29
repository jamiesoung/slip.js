### ! CopyRight: binnng http://github.com/binnng/slip.js, Licensed under: MIT ###
;((WIN, DOC) ->

  UNDEFINED = undefined
  NULL = null

  # 滑动方向中最小允许距离
  MIN_ALLOW_DISTANCE = 10

  # 非滑动方向最大允许距离
  MAX_OPP_ALLOW_DISTANCE = 40

  # CSS前缀
  CSS_PREFIX_MAP = [
    "webkit"
    "moz"
    "ms"
    "o"
    ""
  ]

  NUMBER_REG = /\-?[0-9]+\.?[0-9]*/g

  X = "x"
  Y = "y"
  XY = "xy"

  LEFT = "left"
  RIGHT = "right"
  UP = "up"
  DOWN = "down"

  IsTouch = 'ontouchend' of WIN

  START_EVENT = if IsTouch then 'touchstart' else 'mousedown'

  MOVE_EVENT = if IsTouch then 'touchmove' else 'mousemove'

  END_EVENT = if IsTouch then 'touchend' else 'mouseup'

  WINDOW_HEIGHT = WIN['innerHeight']

  noop = ->


  setTransition = (ele, css) ->
    for prefix in CSS_PREFIX_MAP
      name = if prefix then "#{prefix}Transition" else "transition"
      ele.style[name] = css

  ###
  # 设置元素的CSS位移
  # ele 原生的DOM元素
  ###
  setTranslate = (ele, x, y, z) ->
    for prefix in CSS_PREFIX_MAP
      name = if prefix then "#{prefix}Transform" else "transform"
      ele.style[name] = "translate3d(#{x or 0}px, #{y or 0}px, #{z or 0}px)"

  getTranslate = (ele) ->

    translate = []
    css = ''
    coord = ''

    for prefix in CSS_PREFIX_MAP
      name = if prefix then "#{prefix}Transform" else "transform"

      css = ele.style[name]

      if css and typeof css is 'string'
        coord = css.match(/\((.*)\)/g)[0]
        translate = coord and coord.match NUMBER_REG
        break

    if translate.length
      x: translate[0] or 0
      y: translate[1] or 0
      z: translate[2] or 0


  class Slip

    # 获取事件触发距离
    # 处理一堆兼容
    getCoordinates = (event) ->
      touches = event.touches and ((if event.touches.length then event.touches else [event]))
      e = (event.changedTouches and event.changedTouches[0]) or (event.originalEvent and event.originalEvent.changedTouches and event.originalEvent.changedTouches[0]) or touches[0].originalEvent or touches[0]
      "x": e.clientX
      "y": e.clientY

    constructor: (@ele, @direction) ->


      # 开始的回调
      # 移动中回调
      # 结束的回调
      @onStart = @onMove = @onEnd = noop
      
      # coord: 元素实际坐标值
      # eventCoords: 手指的坐标，用于在各种事件中传递
      # cacheCoords: 当touchstart时候，缓存的当前位移，用于touchmove中计算
      # finger: 手指的位移
      # absFinger: 手指位移的绝对值
      @coord = @eventCoords = @cacheCoords = @finger = @absFinger = NULL

      # 结束后手指滑动的方向
      # 数组 ['left'], ['left', 'up']
      @orient = []

      # webapp当前页
      # 只有设置webapp才有值
      @isWebapp = no

    start : (fn) -> (@onStart = fn) and @
    move  : (fn) -> (@onMove  = fn) and @
    end   : (fn) -> (@onEnd   = fn) and @

    # 设置元素坐标
    setCoord: (userCoords) ->
      coords = @coord = 
        "x": userCoords[X] or 0
        "y": userCoords[Y] or 0

      ele = @ele

      setTranslate ele, coords[X], coords[Y]
      ele.setAttribute attr, coords[attr] for attr of coords

      @

    onTouchStart: (event) ->
      @eventCoords = getCoordinates event

      @cacheCoords = @coord

      # 清空手指位移
      @finger = @absFinger = NULL

      @onWepappStart event if @isWebapp
      ret = @onStart.apply @, [event]

    onTouchMove: (event) ->
      event.preventDefault()

      moveCoords = getCoordinates event

      direction = @direction

      # 手指位移
      # 左滑 finger.x < 0 右滑 finger.x > 0
      # 上滑 finger.y < 0 下滑 finger.y > 0
      finger = @finger = 
        x: moveCoords.x - @eventCoords.x
        y: moveCoords.y - @eventCoords.y

      # 手指位移绝对值
      absFinger = @absFinger = 
        x: Math.abs finger.x
        y: Math.abs finger.y

      # 单方向滑动时，小于正方向最小距离，大于反方向最大距离，不是正确的手指行为
      if direction isnt XY
        # 反方向
        oppDirection = if direction is X then Y else X

        if absFinger[direction] < MIN_ALLOW_DISTANCE or absFinger[oppDirection] > MAX_OPP_ALLOW_DISTANCE
          return no

      # 手指移动方向
      orient = []
      if absFinger.x > MIN_ALLOW_DISTANCE
        orient.push if finger.x < 0 then LEFT else RIGHT

      if absFinger.y > MIN_ALLOW_DISTANCE
        orient.push if finger.y < 0 then UP else DOWN

      @orient = orient

      # 用户返回，如果false，那就不继续了
      ret = @onMove.apply @, [event]

      return no if ret is no



      ele = @ele

      # 元素位移
      eleMove = @coord = 
        "x": if direction.indexOf(X) < 0 then @cacheCoords[X] else @cacheCoords[X] - 0 + finger.x
        "y": if direction.indexOf(Y) < 0 then @cacheCoords[Y] else @cacheCoords[Y] - 0 + finger.y

      setTranslate ele, eleMove[X], eleMove[Y]

      # 在元素上标记位移
      ele.setAttribute attr, eleMove[attr] for attr of eleMove

    onTouchEnd: (event) ->
      ele = @ele

      @onWepappEnd event if @isWebapp
      ret = @onEnd.apply @, [event]

      # 设置一次translate
      # 防止用户改变了translate
      trans = getTranslate this.ele
      this.setCoord trans if trans

    onWepappStart: (event) ->
      setTransition @ele, NULL

    onWepappEnd: (event) ->
      orient = @orient.join ""
      css = ""
      trans = 0

      page = @page
      pageNum = @pageNum
      ele = @ele

      isUp = orient.indexOf("up") > -1
      isDown = orient.indexOf("down") > -1

      page++ if isUp
      page-- if isDown

      if isUp or isDown
        page = pageNum - 1  if page is pageNum
        page = 0  if page is -1

        trans = "-#{page * WINDOW_HEIGHT}"

        setTransition ele, "all .4s ease-in"
        setTranslate ele, 0, trans, 0

        @page = page


    # 初始化
    init: -> 
      @coord = "x": 0, "y": 0

      # 之所以加上下划线方法，是为了给 destroy 用
      onTouchStart = @_onTouchStart = (event) => @onTouchStart event
      onTouchMove = @_onTouchMove = (event) => @onTouchMove event
      onTouchEnd = @_onTouchEnd= (event) => @onTouchEnd event

      ele = @ele
      ele.addEventListener START_EVENT, onTouchStart, no
      ele.addEventListener MOVE_EVENT, onTouchMove, no
      ele.addEventListener END_EVENT, onTouchEnd, no

      # 初始化元素位移
      initMove = @coord = "x": 0, "y": 0

      direction = @direction
      setTranslate ele, initMove[X], initMove[Y]

      ele.setAttribute attr, initMove[attr] for attr of initMove

      @

    # 摧毁元素的滑动
    destroy: ->

      ele = @ele
      ele.removeEventListener START_EVENT, @_onTouchStart, no
      ele.removeEventListener MOVE_EVENT, @_onTouchMove, no
      ele.removeEventListener END_EVENT, @_onTouchEnd, no

      @

    # webapp
    webapp: (@elPages) ->
      @isWebapp = yes
      @page = 0

      elPagesLen = elPages.length
      pageNum = @pageNum = if elPagesLen then elPagesLen else 0

      if pageNum > 0
        ele = this.ele
        ele.style.height = "#{WINDOW_HEIGHT * pageNum}px"

        elPage.style.height = "#{WINDOW_HEIGHT}px" for elPage in elPages



  slip = (ele, direction) ->
    instance = new Slip ele, direction or X
    instance.init()

  WIN.Slip = slip

) window, document