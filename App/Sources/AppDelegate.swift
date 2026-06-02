//
//  AppDelegate.swift
//  metal-proj macOS
//
//  Created by mtakagi on 2025/10/20.
//

import Cocoa
import MetalKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {
  var window : NSWindow!

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    // Insert code here to initialize your application
  }

  func applicationWillTerminate(_ aNotification: Notification) {
    // Insert code here to tear down your application
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

}
