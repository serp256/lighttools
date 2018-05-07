SWFResViewer - Просмотрщик swf/swc иконок

Настройка среды разработки:
Конфиги среды разработки лежат в папке /bat. Нужно задать путь к Flex SDK в файле PathSDK.bat, образец файла - PathSDK.example

При самой первой компиляции в FlashDevelop'е может упасть ошибка
[Fault] exception, information=ReferenceError: Error #1065: Variable _FarmMapEditorWatcherSetupUtil is not defined.
Это нормально, при этом создаются конфиги в /obj и на втором запуске ошибки не будет

Запуск - Run.bat
Сборка .air - PackageApp.bat, перед сборкой скомпилировать в FlashDevelop'е в Release конфигурации