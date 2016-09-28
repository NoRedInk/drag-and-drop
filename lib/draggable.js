// The number of pixels in either the x or y directions you must drag something
// before it counts as being dragged (as opposed to a click)
var distanceToBeginDragging = 2;

// This is necessary to standardize what "clientX" and "clientY" refer to.
// The version we get from "touches" doesn't account for window scroll, whereas
// it does on mouse events. This way, both of them account for it.
function dragCoordinatesFromEvent (event) {
  var touches = event.touches;

  if (typeof touches === "object" && touches.length > 0) {
    var touch = touches[0];

    return {
      x: touch.clientX,
      y: touch.clientY
    };
  } else {
    return {
      x: event.clientX,
      y: event.clientY
    };
  }
}

function cursorCoordinatesFromEvent (event) {
  var touches = event.touches;

  if (typeof touches === "object" && touches.length > 0) {
    var touch = touches[0];

    return {
      x: touch.pageX - window.pageXOffset,
      y: touch.pageY - window.pageYOffset
    };
  } else {
    return {
      x: event.clientX,
      y: event.clientY
    };
  }
}

function setUpDraggableEvents(options) {
  var draggableDataAttr = options.draggableDataAttr;
  var bucketDataAttr = options.bucketDataAttr;
  var bucketQuerySelector = options.bucketQuerySelector;
  var placeholderId = options.placeholderId;
  var onDragStart = options.on.dragStart;
  var onDragStop = options.on.dragStop;
  var onDragMove = options.on.dragMove;
  var offsets = options.offsets;

  var potentiallyDraggingFrom = null;
  var lastClientX = null;
  var lastClientY = null;
  var dragOffsetX = 0;
  var dragOffsetY = 0;

  function getDraggableId(elem) {
    var result = elem.dataset[draggableDataAttr];

    if (result != null) {
      return result;
    } else {
      if (elem.parentElement) {
        return getDraggableId(elem.parentElement)
      } else {
        return null;
      }
    }
  }

  function getDropZoneId(elem) {
    return elem.dataset[bucketDataAttr];
  }

  function isDraggable(elem) {
    return (elem instanceof HTMLElement) && typeof elem.dataset !== "undefined" &&
        (elem.dataset.hasOwnProperty(draggableDataAttr) ||
          isDraggable(elem.parentElement));
  }

  function attemptDragStart(offsetX, offsetY) {
    return function(event) {
      var target = event.target;

      if(isDraggable(target)) {
        // Prevent the usual drag-to-select-text behavior on mousedown
        // as well as drag-to-pan on touchstart.
        event.preventDefault();

        var coordinates = dragCoordinatesFromEvent(event);
        var x = coordinates.x;
        var y = coordinates.y;

        var bounds = target.getBoundingClientRect();

        lastClientX = x;
        lastClientY = y;
        dragOffsetX = x - bounds.left + offsetX;
        dragOffsetY = y - bounds.top + offsetY;

        potentiallyDraggingFrom = target;
      }
    }
  }

  document.addEventListener("mousedown",
    attemptDragStart(offsets.mouse.x, offsets.mouse.y));

  document.addEventListener("touchstart",
    attemptDragStart(offsets.touch.x, offsets.touch.y));

  function handleDragRelease(event) {
    if (potentiallyDraggingFrom === null) {
      onDragStop();
    } else {
      potentiallyDraggingFrom = null;
    }
  }

  ["mouseup", "touchend", "touchcancel"].forEach(function(eventName) {
    document.addEventListener(eventName, handleDragRelease);
  });

  function handleDragMove(event) {
    var coordinates = dragCoordinatesFromEvent(event);
    var x = coordinates.x;
    var y = coordinates.y;

    if ((Math.abs(x - lastClientX) >= distanceToBeginDragging)
      || (Math.abs(y - lastClientY) >= distanceToBeginDragging)
      || (event instanceof MouseEvent && lastClientX === null && lastClientY === null)  // otherwise, initial hovers are skipped
    ) {
      var placeholderPoint = {
        x: x - dragOffsetX,
        y: y - dragOffsetY
      };

      var documentElement = event.target.ownerDocument.documentElement;
      var clientSize = {
        height: window.innerHeight,
        width: window.innerWidth
      };

      if (potentiallyDraggingFrom !== null) {
        potentiallyDraggingFrom = null;

        var draggableId = getDraggableId(event.target);

        if (typeof draggableId === "string") {
          onDragStart({
            draggableId: draggableId,
            point: placeholderPoint
          });
        }
      }

      var placeholder = document.getElementById(placeholderId);

      if (placeholder !== null) {
        var bucketElems = document.querySelectorAll(bucketQuerySelector);
        var bucketPairs = []; // List ( DropZoneId, BoundingClientRect )

        for (var index = 0, length = bucketElems.length; index < length; index++) {
          var bucketElem = bucketElems[index];

          bucketPairs.push([
            getDropZoneId(bucketElem),
            bucketElem.getBoundingClientRect()
          ]);
        }

        onDragMove({
          clientSize: clientSize,
          cursor: cursorCoordinatesFromEvent(event),
          placeholder: {
            point: placeholderPoint,
            bounds: placeholder.getBoundingClientRect()
          },
          bucketBounds: bucketPairs
        });
      }
    }
  }

  ["mousemove", "touchmove"].forEach(function(eventName) {
    document.addEventListener(eventName, handleDragMove);
  });
};

Draggable = { setUpDraggableEvents: setUpDraggableEvents};
