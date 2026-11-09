require "../../spec_helper"

class LayoutOutput < Fingers::Printer
  getter contents = ""

  def print(msg : String)
    @contents += msg
  end

  def flush
  end
end

# Render into a real, isolated tmux grid: string lengths alone cannot detect
# extra wrapping or a bottom-row write that scrolls the entire replica.
class LayoutGrid
  getter directory : String
  @socket : String
  @counter = 0
  @last_pane : String?

  def initialize
    @directory = "/tmp/fingers-grid-#{Process.pid}-#{Random.rand(1000000)}"
    Dir.mkdir(directory)
    @socket = "#{directory}/tmux.sock"
    tmux("-f", "/dev/null", "new-session", "-d", "-s", "grid", "-x", "90", "-y", "8")
    tmux("set-option", "-g", "status", "off")
    tmux("resize-window", "-x", "90", "-y", "8")
  end

  def render(frame : String) : Array(String)
    @counter += 1
    file = "#{directory}/frame-#{@counter}"
    ready = "#{file}.ready"
    File.write(file, "\e[H\e[2J" + frame)
    command = "cat #{Process.quote(file)}; touch #{Process.quote(ready)}; exec sleep 30"
    pane = tmux("new-window", "-d", "-P", "-F", "\#{pane_id}", command).strip
    @last_pane = pane
    100.times do
      break if File.exists?(ready)
      sleep 20.milliseconds
    end
    File.exists?(ready).should be_true
    # The marker is written after cat exits, but the server may still be
    # processing its last PTY output. Wait for the bottom row to arrive.
    rows = [] of String
    100.times do
      rows = tmux("capture-pane", "-p", "-N", "-t", pane).chomp.split('\n')
      break if rows.last?.try(&.starts_with?("BOTTOM"))
      sleep 20.milliseconds
    end
    rows
  end

  def colored_rows : Array(String)
    tmux("capture-pane", "-p", "-e", "-t", @last_pane.not_nil!).chomp.split('\n')
  end

  def close
    tmux("kill-server")
  ensure
    FileUtils.rm_rf(directory)
  end

  private def tmux(*args : String) : String
    output = IO::Memory.new
    error = IO::Memory.new
    status = Process.run("tmux", ["-S", @socket] + args.to_a, output: output, error: error)
    raise error.to_s unless status.success?
    output.to_s
  end
end

describe "physical row rendering" do
  it "keeps CJK, tabs, full-width borders, blank rows and the bottom row in place" do
    grid = LayoutGrid.new
    rows = [
      "HEADER",
      "한" * 40,
      "  src/main.cr",
      "",
      "│" + " " * 88 + "│",
      "가나다\tvalue",
      "X" * 90,
      "BOTTOM".ljust(90),
    ]
    source = rows.map_with_index { |row, index| "\e[#{index + 1};1H#{row}" }.join
    original = grid.render(source)
    original.size.should eq(8)
    original.first.should start_with("HEADER")

    state = Fingers::State.new
    output = LayoutOutput.new
    hinter = Fingers::Hinter.new(
      input: original, width: 90,
      patterns: ["src/main\\.cr"], alphabet: ["a", "b"],
      state: state, output: output, preserve_layout: true,
    )
    hinter.run
    target = ["a", "b"].compact_map { |hint| hinter.lookup(hint) }.first
    expected = original.map(&.rstrip)
    expected[2] = "  #{target.hint}rc/main.cr"
    grid.render(output.contents).map(&.rstrip).should eq(expected)
    colored_match = grid.colored_rows[2]
    colored_match.should match(/\e\[(38;5;2|32)m/)
    colored_match.should match(/\e\[(38;5;3|33)mrc\/main\.cr/)

    # Filtering removes the label without shifting the underlying frame.
    state.input = "z"
    filtered = LayoutOutput.new
    Fingers::Hinter.new(
      input: original, width: 90,
      patterns: ["src/main\\.cr"], alphabet: ["a", "b"],
      state: state, output: filtered, preserve_layout: true,
    ).run
    grid.render(filtered.contents).map(&.rstrip).should eq(original.map(&.rstrip))
  ensure
    grid.try(&.close)
  end
end
