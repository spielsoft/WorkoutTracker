#!/usr/bin/env swift
import ApplicationServices
import AppKit
import Foundation

let expectedLabels = [
  "No workout sheet selected",
  "Choose workout sheet",
  "Create sheet",
]

func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
  var value: AnyObject?
  let result = AXUIElementCopyAttributeValue(element, name as CFString, &value)
  return result == .success ? value : nil
}

func stringAttribute(_ element: AXUIElement, _ name: String) -> String {
  attribute(element, name) as? String ?? ""
}

func pointAttribute(_ element: AXUIElement, _ name: String) -> CGPoint? {
  guard let value = attribute(element, name) else {
    return nil
  }
  guard CFGetTypeID(value) == AXValueGetTypeID() else {
    return nil
  }
  var point = CGPoint.zero
  guard AXValueGetValue(value as! AXValue, .cgPoint, &point) else {
    return nil
  }
  return point
}

func sizeAttribute(_ element: AXUIElement, _ name: String) -> CGSize? {
  guard let value = attribute(element, name) else {
    return nil
  }
  guard CFGetTypeID(value) == AXValueGetTypeID() else {
    return nil
  }
  var size = CGSize.zero
  guard AXValueGetValue(value as! AXValue, .cgSize, &size) else {
    return nil
  }
  return size
}

func frame(of element: AXUIElement) -> CGRect? {
  guard
    let position = pointAttribute(element, kAXPositionAttribute),
    let size = sizeAttribute(element, kAXSizeAttribute)
  else {
    return nil
  }
  return CGRect(origin: position, size: size)
}

func line(for element: AXUIElement) -> String {
  [
    stringAttribute(element, kAXRoleAttribute),
    stringAttribute(element, kAXTitleAttribute),
    stringAttribute(element, kAXDescriptionAttribute),
    stringAttribute(element, kAXValueAttribute),
    stringAttribute(element, kAXHelpAttribute),
  ]
  .filter { !$0.isEmpty }
  .joined(separator: " | ")
}

func runningWorkoutTracker() -> NSRunningApplication? {
  NSWorkspace.shared.runningApplications.first {
    $0.localizedName == "WorkoutTracker"
  }
}

func scan(appElement: AXUIElement, frame: CGRect) -> Set<String> {
  var found = Set<String>()
  let step = 24
  for y in stride(from: Int(frame.minY), through: Int(frame.maxY), by: step) {
    for x in stride(from: Int(frame.minX), through: Int(frame.maxX), by: step) {
      var hit: AXUIElement?
      let result = AXUIElementCopyElementAtPosition(appElement, Float(x), Float(y), &hit)
      guard result == .success, let hit else {
        continue
      }
      let hitLine = line(for: hit)
      if !hitLine.isEmpty {
        found.insert(hitLine)
      }
    }
  }
  return found
}

guard let app = runningWorkoutTracker() else {
  fputs("WorkoutTracker is not running.\n", stderr)
  exit(1)
}

let appElement = AXUIElementCreateApplication(app.processIdentifier)
guard
  let windows = attribute(appElement, kAXWindowsAttribute) as? [AXUIElement],
  let window = windows.first,
  let frame = frame(of: window)
else {
  fputs("Could not locate a WorkoutTracker AX window frame.\n", stderr)
  exit(1)
}

let deadline = Date().addingTimeInterval(8)
var found = Set<String>()
repeat {
  found = scan(appElement: appElement, frame: frame)
  let hasAllExpectedLabels = expectedLabels.allSatisfy { expected in
    found.contains { $0.contains(expected) }
  }
  if hasAllExpectedLabels {
    break
  }
  Thread.sleep(forTimeInterval: 0.25)
} while Date() < deadline

let matchingLines = found
  .filter { line in expectedLabels.contains { line.contains($0) } }
  .sorted()

print("Found expected AX labels:")
for line in matchingLines {
  print(line)
}

let missingLabels = expectedLabels.filter { expected in
  !found.contains { $0.contains(expected) }
}

if !missingLabels.isEmpty {
  fputs("Missing AX labels: \(missingLabels.joined(separator: ", "))\n", stderr)
  fputs("Observed AX lines:\n\(found.sorted().joined(separator: "\n"))\n", stderr)
  exit(1)
}
