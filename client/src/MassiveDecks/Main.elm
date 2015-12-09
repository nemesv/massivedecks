module MassiveDecks.Main where

import Task
import Effects
import Html exposing (Html)
import StartApp
import Json.Decode exposing (decodeString)

import MassiveDecks.Models.State exposing (Model, State(..), LobbyIdAndSecret, Error, Global, InitialState)
import MassiveDecks.Actions.Action exposing (Action(..))
import MassiveDecks.Start as Start
import MassiveDecks.Config as Config
import MassiveDecks.Playing as Playing
import MassiveDecks.Models.Json.Decode exposing (lobbyDecoder)
import MassiveDecks.Util exposing (remove)
import MassiveDecks.UI.General as UI


type SetupModel
  = Waiting
  | Started Model


game : StartApp.App SetupModel
game = StartApp.start
  { init = (Waiting, Effects.none)
  , update = update
  , view = view
  , inputs = [ notificationDecoded, initialStateAction ]
  }


port tasks : Signal (Task.Task Effects.Never ())
port tasks = game.tasks


port notifications : Signal String


port jsAction : Signal (Maybe LobbyIdAndSecret)
port jsAction
  = game.model
  |> Signal.map (\setupModel -> case setupModel of
      Waiting -> Nothing
      Started model -> Just model.jsAction
    )
  |>  Signal.filterMap identity Nothing


port initialState : Signal InitialState


initialStateAction : Signal Action
initialStateAction =
  initialState
  |> Signal.map SetInitialState


notificationDecoded : Signal Action
notificationDecoded =
  notifications
  |> Signal.map (decodeString lobbyDecoder)
  |> Signal.filterMap (Result.toMaybe >> Just) Nothing
  |> Signal.map (\result -> case result of
      Just lobby -> Notification lobby
      Nothing -> NoAction)


main : Signal Html
main = game.html


model : InitialState -> Model
model initialState = Start.model (Global [] initialState) (Start.initialData (Maybe.withDefault "" initialState.gameCode))


update : Action -> SetupModel -> (SetupModel, Effects.Effects Action)
update action setupModel =
  case setupModel of
    Waiting ->
      case action of
        SetInitialState initialState ->
          (Started (model initialState), Effects.none)

        _ ->
          (Waiting, Effects.none)

    Started model ->
      let
        result =
          case action of
            NoAction ->
              (model, Effects.none)

            DisplayError message ->
              let
                global = model.global
              in
                ({ model | global = { global | errors = Error message :: model.global.errors } }, Effects.none)

            RemoveErrorPanel index ->
              let
                global = model.global
              in
                ({ model | global = { global | errors = (remove model.global.errors index) } }, Effects.none)

            _ ->
              case model.state of
                SStart data ->
                  Start.update action model.global data

                SConfig data ->
                  Config.update action model.global data

                SPlaying data ->
                  Playing.update action model.global data
      in
        (Started (fst result), (snd result))


view : Signal.Address Action -> SetupModel -> Html
view address setupModel =
  case setupModel of
    Waiting -> UI.spinner

    Started model ->
      case model.state of
        SStart data ->
          Start.view address model.global data

        SConfig data ->
          Config.view address model.global data

        SPlaying data ->
          Playing.view address model.global data