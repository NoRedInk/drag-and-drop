port module Draggable.Ports exposing (dragStart, dragStop, dragMove, scrollBy)

import Draggable.State exposing (DraggableId, BucketId, Point, Bounds, Size)


scrollBy : Float -> Float -> Cmd a
scrollBy =
    curry scrollByPort


port scrollByPort : ( Float, Float ) -> Cmd msg


port dragStart : ({ draggableId : DraggableId, point : Point } -> msg) -> Sub msg


port dragStop : (() -> msg) -> Sub msg


port dragMove :
    ({ clientSize : Size
     , cursor : Point
     , placeholder :
        { point : Point
        , bounds : Bounds
        }
     , bucketBounds : List ( BucketId, Bounds )
     }
     -> msg
    )
    -> Sub msg
