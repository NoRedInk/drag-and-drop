module Draggable.Update exposing (update, DragMsg(..), subscriptions)

import Draggable.State exposing (DraggableId, Point, BucketId, Bucket, Draggable, State, Bounds, Size, Placeholder)
import Draggable.Ports as Ports
import Dict exposing (Dict)


{-| When you're dragging within this percentage of the top or bottom portions
of the viewport, start scrolling in that direction. We do this as a percentage
rather than as fixed pixels because otherwise when you're really zoomed in,
you are constantly autoscrolling.
-}
autoscrollMaxPercentage : Float
autoscrollMaxPercentage =
    0.2


{-| When you drag something to the top or bottom of the screen, scroll by
this much.
-}
autoscrollAmount : Float
autoscrollAmount =
    10


type DragMsg
    = DragStart { draggableId : DraggableId, point : Point }
    | DragStop
    | DragMove
        { clientSize : Size
        , cursor : Point
        , placeholder :
            { point : Point
            , bounds : Bounds
            }
        , bucketBounds : List ( BucketId, Bounds )
        }


update : DragMsg -> State -> Result String ( State, Cmd DragMsg )
update msg dragInfo =
    case msg of
        DragStart { draggableId, point } ->
            case getDraggableById dragInfo.buckets draggableId of
                Just ( draggable, _, bucketId ) ->
                    ( { dragInfo | placeholder = Just ( point, draggableId, draggable, Just bucketId ) }
                    , Cmd.none
                    )
                        |> Ok

                Nothing ->
                    Err
                        ("Encountered a draggableId "
                            ++ toString draggableId
                            ++ " - which was not in dragInfo.buckets. This should never happen! dragInfo.buckets was: "
                            ++ toString dragInfo.buckets
                        )

        DragMove { clientSize, cursor, placeholder, bucketBounds } ->
            let
                maxTopToScroll =
                    clientSize.height * autoscrollMaxPercentage

                minBottomToScroll =
                    clientSize.height * (1 - autoscrollMaxPercentage)

                commands =
                    if cursor.y > minBottomToScroll then
                        [ Ports.scrollBy 0 autoscrollAmount ]
                    else if cursor.y < maxTopToScroll then
                        [ Ports.scrollBy 0 -autoscrollAmount ]
                    else
                        []
            in
                -- Sometimes JS can send through a DragMove when we're not dragging.
                -- If that happens, discard it.
                case dragInfo.placeholder of
                    Nothing ->
                        ( dragInfo, Cmd.none )
                            |> Ok

                    Just ( _, draggableId, draggable, _ ) ->
                        let
                            maybeBucketId =
                                getMostOverlappingBounds placeholder.bounds bucketBounds
                        in
                            ( { dragInfo | placeholder = Just ( placeholder.point, draggableId, draggable, maybeBucketId ) }
                            , Cmd.batch commands
                            )
                                |> Ok

        DragStop ->
            case dragInfo.placeholder of
                Nothing ->
                    Err "Received a DragStop when dragInfo.placeholder was Nothing. This should never happen!"

                Just ( _, _, _, Nothing ) ->
                    ( { dragInfo | placeholder = Nothing }, Cmd.none )
                        |> Ok

                Just ( _, draggableId, draggable, Just bucketId ) ->
                    let
                        newBuckets =
                            dropInto draggableId bucketId dragInfo.buckets
                    in
                        ( { dragInfo | placeholder = Nothing, buckets = newBuckets }, Cmd.none )
                            |> Ok


getDraggableById : Dict BucketId Bucket -> DraggableId -> Maybe ( Draggable, Bucket, BucketId )
getDraggableById buckets draggableId =
    getDraggableByIdHelp draggableId (Dict.toList buckets)


getDraggableByIdHelp : DraggableId -> List ( BucketId, Bucket ) -> Maybe ( Draggable, Bucket, BucketId )
getDraggableByIdHelp draggableId bucketPairs =
    case bucketPairs of
        [] ->
            Nothing

        ( bucketId, bucket ) :: rest ->
            case Dict.get draggableId bucket.draggables of
                Nothing ->
                    getDraggableByIdHelp draggableId rest

                Just draggable ->
                    Just ( draggable, bucket, bucketId )


dropInto : DraggableId -> BucketId -> Dict BucketId Bucket -> Dict BucketId Bucket
dropInto draggableId destBucketId buckets =
    case Dict.get destBucketId buckets of
        Nothing ->
            -- The destination does not exist. Do nothing.
            buckets

        Just destBucket ->
            if Dict.member draggableId destBucket.draggables then
                -- We're moving it from A to A. In other words, do nothing.
                buckets
            else
                case getDraggableById buckets draggableId of
                    Nothing ->
                        -- We couldn't find the original draggableId. What is it?! Who is it?!
                        buckets

                    Just ( draggable, sourceBucket, sourceBucketId ) ->
                        let
                            isOverCapacity =
                                case destBucket.capacity of
                                    Nothing ->
                                        False

                                    Just capacity ->
                                        capacity <= Dict.size destBucket.draggables

                            newSourceDraggables =
                                if isOverCapacity then
                                    let
                                        maybeEvictedDraggable =
                                            destBucket.draggables
                                                |> Dict.toList
                                                |> List.head
                                    in
                                        case maybeEvictedDraggable of
                                            Nothing ->
                                                -- We couldn't evict anything, so the drop failed
                                                sourceBucket.draggables

                                            Just ( evictedDraggableId, evictedDraggable ) ->
                                                sourceBucket.draggables
                                                    |> Dict.insert evictedDraggableId evictedDraggable
                                                    |> Dict.remove draggableId
                                else
                                    Dict.remove draggableId sourceBucket.draggables

                            newDestDraggables =
                                if isOverCapacity then
                                    let
                                        maybeEvictedDraggableId =
                                            destBucket.draggables
                                                |> Dict.toList
                                                |> List.head
                                    in
                                        case maybeEvictedDraggableId of
                                            Nothing ->
                                                -- We couldn't evict anything, so the drop failed
                                                destBucket.draggables

                                            Just ( evictedDraggableId, evictedDraggable ) ->
                                                destBucket.draggables
                                                    |> Dict.insert draggableId draggable
                                                    |> Dict.remove evictedDraggableId
                                else
                                    Dict.insert draggableId draggable destBucket.draggables
                        in
                            buckets
                                |> Dict.insert sourceBucketId { sourceBucket | draggables = newSourceDraggables }
                                |> Dict.insert destBucketId { destBucket | draggables = newDestDraggables }


{-| Based on http://math.stackexchange.com/a/99576
-}
getOverlapArea : Bounds -> Bounds -> Float
getOverlapArea d0 d1 =
    let
        xOverlap =
            min d0.right d1.right - max d0.left d1.left

        yOverlap =
            min d0.bottom d1.bottom - max d0.top d1.top
    in
        (xOverlap * yOverlap)
            |> max 0


getMostOverlappingBounds : Bounds -> List ( identifier, Bounds ) -> Maybe identifier
getMostOverlappingBounds =
    getMostOverlappingBoundsHelp 0 Nothing


getMostOverlappingBoundsHelp :
    Float
    -> Maybe identifier
    -> Bounds
    -> List ( identifier, Bounds )
    -> Maybe identifier
getMostOverlappingBoundsHelp area winner elem candidates =
    case candidates of
        [] ->
            winner

        ( candidateId, candidateBounds ) :: rest ->
            let
                candidateOverlapArea =
                    getOverlapArea elem candidateBounds
            in
                if candidateOverlapArea > area then
                    getMostOverlappingBoundsHelp
                        candidateOverlapArea
                        (Just candidateId)
                        elem
                        rest
                else
                    getMostOverlappingBoundsHelp
                        area
                        winner
                        elem
                        rest


subscriptions : State -> Sub DragMsg
subscriptions state =
    if state.placeholder == Nothing then
        Ports.dragStart DragStart
    else
        Sub.batch
            [ Ports.dragMove DragMove
            , Ports.dragStop (\_ -> DragStop)
            ]
