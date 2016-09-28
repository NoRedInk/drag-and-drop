module Example exposing (..)

import Dict exposing (Dict)
import Draggable.Update
import Html exposing (..)
import Html.Attributes exposing (..)
import Draggable.State exposing (State, ViewableDraggable(..), DraggableId, BucketId, Bucket)
import Draggable.Update
import Html exposing (..)
import Html.Attributes exposing (..)
import Dict exposing (Dict)


type alias Model =
    { dragState : State }


type Msg
    = DragMsg Draggable.Update.DragMsg


main : Program Never Model Msg
main =
    Html.program
        { view = view
        , init = ( initialModel, Cmd.none )
        , update = update
        , subscriptions = subscriptions
        }


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.map DragMsg (Draggable.Update.subscriptions model.dragState)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        DragMsg dragMsg ->
            case Draggable.Update.update dragMsg model.dragState of
                Ok ( newDragState, cmd ) ->
                    ( { model | dragState = newDragState }, Cmd.map DragMsg cmd )

                Err _ ->
                    ( model, Cmd.none )


initialModel : Model
initialModel =
    { dragState =
        { placeholder = Nothing
        , buckets =
            Dict.fromList
                [ ( "bucket_1"
                  , { draggables =
                        Dict.fromList
                            [ ( "draggable_1"
                              , { content = div [ style [ ( "width", "150px" ), ( "height", "100px" ), ( "display", "inline-block" ), ( "background-color", "aliceblue" ) ] ] [] }
                              )
                            , ( "draggable_2"
                              , { content = div [ style [ ( "width", "100px" ), ( "height", "100px" ), ( "display", "inline-block" ), ( "background-color", "rebeccapurple" ) ] ] [] }
                              )
                            ]
                    , capacity = Nothing
                    }
                  )
                , ( "bucket_2"
                  , { draggables =
                        Dict.fromList
                            [ ( "draggable_3"
                              , { content = div [ style [ ( "width", "50px" ), ( "height", "100px" ), ( "display", "inline-block" ), ( "background-color", "gray" ) ] ] [] }
                              )
                            , ( "draggable_4"
                              , { content = div [ style [ ( "width", "75px" ), ( "height", "100px" ), ( "display", "inline-block" ), ( "background-color", "black" ) ] ] [] }
                              )
                            ]
                    , capacity = Nothing
                    }
                  )
                ]
        }
    }


view : Model -> Html Msg
view { dragState } =
    let
        ( placeholder, maybeHiddenDraggableId, maybeEligibleBucketId ) =
            case dragState.placeholder of
                Just ( point, draggableId, draggable, maybeBucketId ) ->
                    ( viewDraggable (Just draggableId) (PlaceholderDraggable point draggable)
                    , Just draggableId
                    , maybeBucketId
                    )

                Nothing ->
                    ( text ""
                    , Nothing
                    , Nothing
                    )
    in
        div [ class "example-area" ]
            [ h4 [] [ text "Drag these to different buckets." ]
            , div [] (List.indexedMap (viewBucket maybeHiddenDraggableId maybeEligibleBucketId) (Dict.toList dragState.buckets))
            , placeholder
            ]


viewBucket : Maybe DraggableId -> Maybe BucketId -> Int -> ( BucketId, Bucket ) -> Html a
viewBucket maybeHiddenDraggableId maybeEligibleBucketId index ( bucketId, bucket ) =
    div
        [ attribute "data-bucket-id" bucketId
        , class "bucket-container"
        , style [ ( "padding", "20px" ), ( "background-color", "rgb(100, " ++ toString (index * 100) ++ ", 0)" ) ]
        ]
        (List.map (uncurry NonPlaceholderDraggable >> viewDraggable maybeHiddenDraggableId) (Dict.toList bucket.draggables))


draggableClass : Attribute msg
draggableClass =
    class "draggable"


viewDraggable : Maybe DraggableId -> ViewableDraggable -> Html a
viewDraggable maybeHiddenDraggableId viewableDraggable =
    let
        ( draggable, attrs ) =
            case viewableDraggable of
                NonPlaceholderDraggable draggableId draggable ->
                    let
                        styles =
                            if maybeHiddenDraggableId == Just draggableId then
                                [ ( "visibility", "hidden" ) ]
                            else
                                []
                    in
                        ( draggable
                        , [ draggableClass
                          , style styles
                          , attribute "data-draggable-id" draggableId
                          ]
                        )

                PlaceholderDraggable point draggable ->
                    let
                        styles =
                            [ ( "position", "fixed" )
                            , ( "left", ((toString point.x) ++ "px") )
                            , ( "top", ((toString point.y) ++ "px") )
                            , ( "margin", "0" )
                            ]
                    in
                        ( draggable
                        , [ draggableClass
                          , style styles
                          , id "draggable-placeholder"
                          ]
                        )
    in
        div attrs [ Html.map never draggable.content ]
