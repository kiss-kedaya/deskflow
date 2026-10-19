# SPDX-FileCopyrightText: (C) 2024 Chris Rizzitello <sithlord48@gmail.com>
# SPDX-License-Identifier: MIT

# HACK This is set when the files is included so its the real path
# calling CMAKE_CURRENT_LIST_DIR after include would return the wrong scope var
set(MY_DIR ${CMAKE_CURRENT_LIST_DIR})
set(OSX_BUNDLE ${BUILD_OSX_BUNDLE})

set(OS_STRING "macos-${BUILD_ARCHITECTURE}")

if (OSX_BUNDLE)
  set(_codesign_identity "-")
  if (APPLE_CODESIGN_DEV)
    set(_codesign_identity "${APPLE_CODESIGN_DEV}")
  endif()

  # Hardened runtime turns on library validation, so every nested framework has
  # to be signed by the same Team ID as the main binary. macdeployqt leaves the
  # Qt frameworks signed by Qt, which makes dyld refuse to load them for an
  # ad-hoc signed build. Only ask for hardened runtime when we have a real
  # Developer ID to sign everything with.
  set(_hardened_runtime "")
  if (APPLE_CODESIGN_DEV)
    set(_hardened_runtime "-hardened-runtime -timestamp")
  endif()

  install(CODE "execute_process(COMMAND
    ${DEPLOYQT}
    \"\${CMAKE_INSTALL_PREFIX}/${CMAKE_PROJECT_PROPER_NAME}.app\"
    ${_hardened_runtime} \"-codesign=${_codesign_identity}\"
  )")

  # Re-sign every nested framework and the bundle itself with one identity, so
  # the packaged app launches even without a Developer ID certificate.
  install(CODE "
    set(_app \"\${CMAKE_INSTALL_PREFIX}/${CMAKE_PROJECT_PROPER_NAME}.app\")
    file(GLOB _frameworks \"\${_app}/Contents/Frameworks/*.framework\")
    foreach(_fw \${_frameworks})
      execute_process(COMMAND /usr/bin/codesign --force --sign \"${_codesign_identity}\" \"\${_fw}\")
    endforeach()
    file(GLOB_RECURSE _libs \"\${_app}/Contents/Frameworks/*.dylib\")
    foreach(_lib \${_libs})
      execute_process(COMMAND /usr/bin/codesign --force --sign \"${_codesign_identity}\" \"\${_lib}\")
    endforeach()
    execute_process(COMMAND /usr/bin/codesign --force --deep --sign \"${_codesign_identity}\" \"\${_app}\")
  ")

  set(CPACK_PACKAGE_ICON "${MY_DIR}/dmg-volume.icns")
  set(CPACK_DMG_BACKGROUND_IMAGE "${MY_DIR}/dmg-background.tiff")
  set(CPACK_DMG_DS_STORE_SETUP_SCRIPT "${MY_DIR}/generate_ds_store.applescript")
  set(CPACK_DMG_VOLUME_NAME "${CMAKE_PROJECT_PROPER_NAME}")
  set(CPACK_DMG_SLA_USE_RESOURCE_FILE_LICENSE ON)
  set(CPACK_GENERATOR "DragNDrop")
endif()
