# Full-scope acceptance inventory

All items OPEN. IDs below trace to immutable original blocks; the private full-text inventory retains every source detail. No scope is dropped by execution slicing.

- **1. Обзор** — source `b1308f62-96e2-4ac1-997b-a1e8787a9785`.
- **2. Принципы разработки и стек** — source `81569dc5-22df-4fb3-948b-ce5cc4f07fc6`.
- **3. Модуль полноэкранного текста command_overlay** — source `73663d83-549c-4826-b4fd-eb9f19739dfc`.
- **4. Система приказов и давление временем** — source `853ae795-2200-47ec-b164-2c744e343aa3`.
- **5. Сценарий и поток игры** — source `e41eee13-f4d5-456c-a8af-d749f873f8fb`.
- **6. Трансформация игрока** — source `f19113da-8cc6-4ea9-a3e9-f8b60cd7fc70`.
- **7. Финальное задание: яма** — source `adf47a21-8992-49ef-b069-5ec88b47c5bd`.
- **8. Окружение и арт-дирекшн** — source `422fac11-273d-42ac-a521-dbaa09883a8f`.
- **9. Пост-обработка и эффекты камеры** — source `e7598e13-eeef-4618-ab9f-c333d3a1eacd`.
- **10. Звук** — source `9d09a902-6981-431e-9b05-4f7bc1cf6e3f`.
- **11. Каталог готовых ассетов и решений** — source `6534f255-b9ba-4045-98fb-1a19c3deda78`.
- **12. Архитектура проекта** — source `2d254ae5-a226-4167-a2d0-593fe33dfe73`.
- **13. Этапы и критерии приёмки** — source `8a35a5f2-5913-4fde-a700-a8c04465b046`.

## Final release gates

- [ ] R01: Полное прохождение занимает 8–15 минут, в консоли нет ошибок и предупреждений. — `2855a24d-3310-48b1-b227-0b9ff29004de`
- [ ] R02: Лестница 20 → 10 → 5 → 3 → 2 → 1 с работает на каждом задании; провал показывает «BAD DOG» и возвращает в меню. — `d2da3cad-d6f8-4292-adbe-0911efef1b6a`
- [ ] R03: Клавиша, закрывшая надпись, не засчитывается как действие в игре. — `052309e6-11c7-471b-a1c1-3ffe273934ef`
- [ ] R04: Лай не по приказу вызывает «QUIET.» без штрафа по времени. — `a7f886b7-5a57-44cd-963f-184280793346`
- [ ] R05: Пять шагов трансформации соответствуют таблице раздела 6 с допуском ±5%. — `16b0179e-90ec-43db-91eb-8c5d6bf5b1f2`
- [ ] R06: У ямы расстояние до центра не растёт ни при каком вводе: автотест 60 с случайного ввода и скольжения вдоль стен. — `11020cc6-658a-419c-9c34-0a621807254c`
- [ ] R07: Папка command_overlay, скопированная в пустой проект Godot 4.7, работает без правок. — `fe387de3-8811-4f1b-b559-568f5c358b7c`
- [ ] R08: Каждый сторонний ассет записан в THIRD_PARTY.md с лицензией и ссылкой; NC-лицензий нет. — `9bff2143-bb74-402c-92c8-5fdc2b0d0171`
- [ ] R09: 60 FPS в 1080p на GTX 1060 / RX 580. — `5b37cc9c-7a94-491d-a16e-1aa16c5ee1f4`
- [ ] R10: Экран предупреждения и опции «Уменьшить вспышки», «Уменьшить тряску» работают. — `32184c0d-e8b0-4e26-8ab6-786ae62fced3`
- [ ] R11: Плейтест на 5+ людях: минимум 4 из 5 без подсказки описывают ощущения словами из ряда «давление», «подчинение», «унижение», «беспомощность». — `a079aaa8-acfd-4055-aa80-a2dc832a7641`

## Additional delivery gates

- [ ] Each of seven original phases has a playable build and walkthrough video; parent independently accepts before next phase.
- [ ] Warning-free Godot import and tests; visual/audio playthrough is separate from headless checks.
- [ ] Windows and Linux exports installed and launched; no secrets/private source in public repository.
- [ ] Public repository under coca-in-a-cola (not coca-in-a-cola-iaac); develop checkpoint verified against remote.
- [ ] Explicit original-code license selected; every imported dependency/file has verified provenance and retained license/credits.
- [ ] Style guide and per-object articles updated to reflect actual implementation.

## Clarifications / inconsistencies (preserve original)

- Source code fences label GDScript examples `javascript`; preserve verbatim original, use GDScript in implementation.
- Four irreversible transitions plus initial state make five table rows; step 4 occurs on pit-room entry, not after JUMP.
- Overlay FLASH does not pause; timer starts after dismissal for other modes. The final 1-second rung needs explicit tested semantics.
- Real-time 0.35-second input lock and 0.25-second thaw must survive tree pause/time_scale; no dismissal input leaks as bark.
- Source audio tables number pressure steps 1–6 while controllers use levels 0–5; map explicitly.
- Sonniss custom royalty-free/no-training license is outside blanket preapproved list: evaluate exact distribution terms or choose CC0, never assume CC0.
- Headless success does not prove Forward+ rendering, GPU performance, video, human playtests, or audio loudness.
