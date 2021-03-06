module Main where

import StartApp
import Html exposing (..)
import Dict exposing (Dict)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as JD exposing ((:=))
import Json.Encode as JE
import Signal exposing (Mailbox, Address, mailbox, message)
import Task exposing (Task, andThen)
import Effects exposing (Effects, Never)

import ElmFire
import ElmFire.Dict
import ElmFire.Op

config : StartApp.Config Model Action
config =
  { init = (initialModel, initialEffect)
  , update = updateState
  , view = view
  , inputs = [Signal.map FromServer inputVotes]
  }

firebaseUrl : String
firebaseUrl = "https://collab-counter.firebaseio.com/counter0"

syncConfig : ElmFire.Dict.Config Vote
syncConfig =
  { location = ElmFire.fromUrl firebaseUrl
  , orderOptions = ElmFire.noOrder
  , encoder =
      \m -> case m of
        Upvote i -> JE.object [ ("upvote", JE.int i) ]
        Downvote i -> JE.object [ ("downvote", JE.int i) ]
  , decoder =
      ( JD.oneOf
        [ JD.map Upvote ("upvote" := JD.int)
        , JD.map Downvote ("downvote" := JD.int)
        ]
      )
  }

app : StartApp.App Model
app = StartApp.start config

port runEffects : Signal (Task Never ())
port runEffects = app.tasks

main : Signal Html
main = app.html

type Vote = Upvote Int | Downvote Int
type alias Id = String
type alias Votes = Dict Id Vote

type alias Model =
  { votes: Votes
  }

initialModel : Model
initialModel =
  { votes = Dict.empty
  }

type Action = FromGui GuiEvent
            | FromServer Votes
            | FromEffect -- no actions from effects

-- An event that originates from the UI on this page.
type GuiEvent
  = NoOpEvent
  | UpvoteEvent
  | DownvoteEvent

type alias GuiAddress = Address GuiEvent

(initialTask, inputVotes) = ElmFire.Dict.mirror syncConfig

initialEffect : Effects Action
initialEffect = initialTask |> kickOff

{- Map any task to an effect, discarding any direct result or error value -}
kickOff : Task x a -> Effects Action
kickOff =
  Task.toMaybe >> Task.map (always (FromEffect)) >> Effects.task

effectVotes : ElmFire.Op.Operation Vote -> Effects Action
effectVotes operation =
  ElmFire.Op.operate syncConfig operation |> kickOff

updateState : Action -> Model -> (Model, Effects Action)
updateState action model =
  case action of

    FromEffect ->
      ( model
      , Effects.none
      )

    FromServer (newModel) ->
      ( { model | votes <- newModel }
      , Effects.none
      )

    FromGui UpvoteEvent ->
      ( model
      , effectVotes <| ElmFire.Op.push (Upvote 1)
      )

    FromGui DownvoteEvent ->
      ( model
      , effectVotes <| ElmFire.Op.push (Downvote 1)
      )

type alias AugModel = {
  voteCount: Int
}

voteToNum : Vote -> Int
voteToNum v = case v of
  Upvote i -> i
  Downvote i -> -1 * i

augment : Model -> AugModel
augment model =
  let count = List.foldl (\a b -> b + (voteToNum a)) 0 (Dict.values model.votes)
  in { voteCount = count }

view : Address Action -> Model -> Html
view actionAddress model =
  let augModel = augment model
      guiAddress = Signal.forwardTo actionAddress FromGui
  in div [ class "row btn-group btn-group-justified" ]
    [ div [ class "col-xs-4" ]
      [ button [ onClick guiAddress DownvoteEvent
               , class "btn btn-default btn-block" ]
               [ span [ class "glyphicon glyphicon-arrow-down" ] [] ] ]
    , div [ class "col-xs-4 text-center" ] [ text (toString augModel.voteCount) ]
    , div [ class "col-xs-4" ]
      [ button [ onClick guiAddress UpvoteEvent
               , class "btn btn-default btn-block" ]
               [ span [ class "glyphicon glyphicon-arrow-up" ] [] ] ]
    ]
