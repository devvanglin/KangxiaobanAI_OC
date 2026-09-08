@echo off
set "DEVECO_SDK_HOME=C:\Program Files\Huawei\DevEco Studio\sdk"
set "JAVA_HOME=C:\Program Files\Huawei\DevEco Studio\jbr"
set "NODE_HOME=C:\Program Files\Huawei\DevEco Studio\tools\node"
cd /d D:\Coding\KangxiaobanAI_OC\KangxiaobanAI
call "C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat" --mode module -p product=default -p buildMode=debug assembleHap
