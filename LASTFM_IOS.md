# iOS + Last.fm (unsigned IPA для LiveContainer)

Этот форк = upstream Mornye + два гейта, включающих Last.fm на iOS.
`lib/services/music_player_runtime.dart` и `lib/screens/settings/playback_settings_page.dart`.

Лицензия: LGPL/GPL, как и upstream. Discord Presence на iOS собирается stub-ом
(`MORNYE_DISCORD_SDK=0`) — приватный партнёрский SDK здесь недоступен.

## 1. Регистрация Last.fm API

https://www.last.fm/api/account/create (бесплатно). Нужны `API key` и `Shared secret`.
В репозитории их быть не должно — только в Secrets форка.

## 2. Secrets форка

Settings → Secrets and variables → Actions → New repository secret:

| Имя | Значение |
|---|---|
| `LASTFM_API_KEY` | вашего приложения |
| `LASTFM_API_SECRET` | вашего приложения |

## 3. Сборка

Actions → **iOS Last.fm (unsigned IPA)** → Run workflow.
Через ~15–25 минут в Summary запуска — артефакт `ios-ipa-lastfm` с
`Mornye-ios-lastfm-unsigned.ipa`.

## 4. Установка через LiveContainer

1. Скачать IPA на телефон (Files / браузер / Sync через Telegram — без разницы).
2. LiveContainer → «Import IPA» → выбрать файл → Install.
3. LiveContainer сам переподпишет development-сертификатом.

## 5. Включение скробблинга

Mornye → Settings → Playback → Last.fm → «Connect» → кнопка открывает Last.fm
в браузере → подтвердить → возврат в Mornye. После этого: now playing +
scrobbles пишутся с этого телефона (только локально воспроизводимый плеер —
не каталог/стриминг-расширения).

## Обновление форка от upstream

```sh
git fetch upstream
git rebase upstream/main    # или merge
# два файла с Git-диффом могут конфликтовать редко — правки гейтов точечные
```

Upstream сам Last.fm на iOS не включает (десктоп-only); это поведение форка,
листайте этот файл и коммиты `feat: enable Last.fm on iOS*` при разрешении конфликтов.
