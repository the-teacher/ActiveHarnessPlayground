class AppMemory < ActiveHarness::Memory
  # Usage: AppMemory.new(session_id: "user_42")
  #
  # Wraps ActiveHarness::Memory with application-wide defaults.
  # Callers only need to pass a session_id — all other options
  # are centrally configured here.

  STORAGE_PATH = File.expand_path("../../../storage/ai/memory", __dir__).freeze

  def initialize(session_id:)
    super(
      session_id:   session_id,
      depth:        10,
      adapter:      :file,
      path:         STORAGE_PATH,
      storage_size: 200,
      pretty:       true
    )
  end
end
