{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    renderer: "canvaskit", // Forces CanvasKit renderer for maximum performance and smooth gaming animations
  },
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
});
