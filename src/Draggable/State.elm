module Draggable.State exposing (DraggableId, BucketId, Point, Bucket, Draggable, State, Placeholder, ViewableDraggable(..), Bounds, bucketIdFromInt, Size)

import Dict exposing (Dict)
import Html exposing (Html)


type alias BucketId =
    String


type alias DraggableId =
    String


type alias Point =
    { x : Float, y : Float }


type alias State =
    { placeholder : Maybe Placeholder
    , buckets : Dict BucketId Bucket
    }


type alias Bucket =
    { draggables : Dict DraggableId Draggable
    , capacity : Maybe Int
    }


type alias Draggable =
    { content : Html Never }


type ViewableDraggable
    = PlaceholderDraggable Point Draggable
    | NonPlaceholderDraggable DraggableId Draggable


type alias Placeholder =
    ( Point, DraggableId, Draggable, Maybe BucketId )


type alias Bounds =
    { top : Float, left : Float, bottom : Float, right : Float }


toBucket : Int -> ( BucketId, Bucket )
toBucket index =
    ( bucketIdFromInt index, { draggables = Dict.empty, capacity = Just 1 } )


toDraggable : String -> ( DraggableId, Draggable )
toDraggable sentence =
    -- Use the sentence as the unique ID, since they're in a Set.
    -- TODO add a chore for supporting buckets with pre-populated draggables
    -- what we need to do there is to add the draggable ahead of time, and then
    -- assign it to the appropriate drop zone once that drop zone has an ID.
    ( sentence, { content = Html.text sentence } )


bucketIdFromInt : Int -> BucketId
bucketIdFromInt num =
    "DROP_ZONE_" ++ toString num


type alias Size =
    { height : Float
    , width : Float
    }
