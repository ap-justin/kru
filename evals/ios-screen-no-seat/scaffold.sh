#!/bin/bash
# a swiftui app beside a react web app
set -e
mkdir -p ios/Giving web/src
cat > ios/Giving/GivingApp.swift <<'J'
import SwiftUI

@main
struct GivingApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}
J
cat > ios/Giving/ContentView.swift <<'J'
import SwiftUI

struct ContentView: View {
    var body: some View { NavigationStack { Text("Your giving").navigationTitle("Home") } }
}
J
cat > web/package.json <<'J'
{ "name": "web", "private": true, "dependencies": { "react": "19.1.1" } }
J
git init -q && git add -A && git -c user.email=e@e -c user.name=e commit -qm init
