# Hide Development Notice — investigation

Evidence collected from Manor Lords **0.8.104**, installed Steam build **24905706**, Unreal Engine **5.5**, with UE4SS **v3.0.1 Beta #0 / 0bfec09e**. Historical 0.8.090 dumps helped locate candidate names; current assets and live objects established the target. Historical names alone are not accepted as proof.

## 1. What exact classes, widgets, and functions are involved?

| Role | Verified identifier |
| --- | --- |
| Notice class | `/Game/UI/Elements/EarlyAccessWidget.EarlyAccessWidget_C` |
| Notice superclass | `NaviUi` |
| Owning menu pawn | `/Game/CPP_BP/MenuPawn.MenuPawn_C` |
| Startup map | `/Game/NotStronghold/Maps/MainMenu` |
| Normal main-menu widget | `/Game/UI/Main_Menu/mainMenu_widget.mainMenu_widget_C` |
| Pawn's notice reference | `EarlyAccessDialog` |
| Pawn's main-menu reference | `mainMenu` (Unreal FName lookup ignores case) |
| Notice children | `Header` and `nda_txt_1` (`TextBlock`), `Button` (`Button`) |
| Notice initialization | `Construct` |
| Normal dismiss action | `DoFinish`, with no arguments |
| Dismiss event dispatcher | `OnDone` |
| Mouse button callback | `BndEvt__NDA_widget_Button_K2Node_ComponentBoundEvent_0_OnButtonReleasedEvent__DelegateSignature` |
| Controller input route | `HandleInput`, key value `1`, calls `DoFinish` |

The owner startup graph uses `ReceiveBeginPlay`, `IsStartDialogAllowed`, and `introMsgShown`. Native menu types include `MenuPawn` and `MLMainMenuScreen`; the latter's existence is not a reason to intercept every menu dialog. The mod does not hook a delegate signature.

## 2. Where does the notice appear in the startup flow?

`MenuPawn_C:ReceiveBeginPlay` creates the normal main menu and evaluates the game's startup-dialog conditions. When `introMsgShown` is false and `IsStartDialogAllowed` permits it, the normal build creates `EarlyAccessWidget_C` and stores it in `EarlyAccessDialog`. A separate developer/nonconsole branch uses `NdaDialog`.

In the live menu, the post-`ReceiveBeginPlay` point already has a valid notice, initialized text, viewport membership, the normal owning controller, and focus on the notice. No wait or retry is needed in the investigated build.

## 3. How is this development notice uniquely identified?

The implementation requires the exact notice class and expected startup map, the exact owning pawn and normal main-menu relationship, and the pawn's `EarlyAccessDialog` reference. It verifies each expected child's class and outer relationship. It also requires the title **“This game is still in development”** and the complete verified English body, with whitespace normalized, plus the expected focus and a resident zero-argument `DoFinish` function.

The notice's `Construct` graph obtains localized text from `DT_Translation_Menus`, using `early_access_msg` and `early_access_msg_descr`; WinGDK has Xbox-specific alternatives. Class-default FText values are overwritten during construction, so they are not sufficient for runtime matching. Only the verified English title and full body are supported by this version. Other languages remain visible.

## 4. What is the safest hook point?

Use the post hook on `/Game/CPP_BP/MenuPawn.MenuPawn_C:ReceiveBeginPlay`. It runs after the owner has created and initialized the target in the investigated startup flow. The hook only examines that owner and its exact notice reference.

UE4SS requires a hook's UFunction to exist in memory before registration. Its documented Blueprint-path hook behavior runs the callback after the function. Hook context must be unwrapped with `Context:get()`. [RegisterHook documentation](https://docs.ue4ss.com/dev/lua-api/global-functions/registerhook.html)

The implementation registers this lifecycle hook once after its function becomes available, using one native `MenuPawn` construction notification to identify the exact Blueprint class. Successful registration removes the construction watcher. It uses no generic modal, text, input, or every-widget hook. The post-event callback runs on the menu's game thread and validates and dismisses synchronously; object validity is checked before access. [Construction notification API](https://docs.ue4ss.com/dev/lua-api/global-functions/notifyonnewobject.html), [validity API](https://docs.ue4ss.com/lua-api/classes/remoteobject.html)

## 5. Is hiding the widget or normal dismissal safer?

Normal dismissal is the safer supported action here. The asset graph shows `DoFinish` removing the notice from its parent, calling `PlaySound2D` twice, and broadcasting `OnDone`. Both the mouse button and controller path use it. There are no save writes in this action, and the owner graph contains no binding or reference to `OnDone`.

Calling this validated action preserves the notice's own navigation and removal behavior. Merely hiding or collapsing a focused modal could leave its input or navigation state active. The mod therefore lets the game create the notice and calls `DoFinish` only after every identification check succeeds. It does not manually broadcast `OnDone` or invoke an arbitrary button callback.

## 6. Does the game recreate the notice later in the same session?

The startup graph sets `introMsgShown` to true when it creates the dialog, blocking the same startup branch from creating it again during that session. The mod does not change this flag or any global startup-dialog setting. A later game change that introduces another creation path is unsupported until investigated.

## 7. Could another popup match the detection?

A different popup does not qualify through a generic class, a close button, or a short phrase. It would have to match the exact notice class, owner reference, map, main-menu relationship, child classes and outers, complete expected title and body, focus, and dismissal signature together.

A future update could reuse all those identifiers and the same complete text for different behavior. That remains a limit of reflection-based identification. Changed text, structure, ownership, or signature is rejected, and there is no generic suppression fallback.

## 8. Is polling required?

No. The verified owner's post-`ReceiveBeginPlay` event exposes the initialized notice directly. The mod has no Tick callback, recurring timer, continuous object search, delayed retry, or per-frame logging.

## 9. How does the mod fail after a future update?

Missing functions or properties, invalid objects, changed classes, unexpected owners, another map or menu, changed text, unsupported languages, changed focus, and changed dismissal signatures cause the mod to do nothing. The game's notice stays visible and can be dismissed normally. Hook-registration failure is reported once; validation failures are reported without repeating every frame. The mod never switches to hiding unknown dialogs.

## Validation status

Version **0.1.0** passes the recorded launch, menu, rejection, removal, and save checks. The exact release files dismissed the notice on a fresh launch with one success log message. Settings and Load Game remained usable. Removing the mod restored the notice. The automated suite passed **72 tests**, and all **29 save files** were unchanged by count, length, and SHA-256 hash.

See [validation results and limits](VALIDATION.md). Future announcements and game updates cannot be tested before they exist; unmatched-message and changed-target behavior is covered by rejection tests and the absence of any generic dialog suppression.
