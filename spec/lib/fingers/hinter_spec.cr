require "spec"
require "../../spec_helper.cr"
require "../../../src/fingers/hinter"
require "../../../src/fingers/state"
require "../../../src/fingers/config"

record StateDouble, selected_hints : Array(String)

class TextOutput < ::Fingers::Printer
  def initialize
    @contents = ""
  end

  def print(msg)
    self.contents += msg
  end

  def flush
  end

  property :contents
end

def generate_lines
  input = 50.times.map do
    10.times.map do
      rand.to_s.split(".").last[0..15].rjust(16, '0')
    end.join(" ")
  end.join("\n")
end

describe Fingers::Hinter do
  it "retains hint and selected-match styles with physical row rendering" do
    output = TextOutput.new
    state = ::Fingers::State.new
    hinter = Fingers::Hinter.new(
      input: ["prefix: src/main.cr suffix"], width: 80,
      patterns: ["prefix: (?<match>src/main\\.cr)"],
      state: state, output: output, alphabet: ["a", "b"],
      preserve_layout: true,
    )
    hinter.run
    target = ["a", "b"].compact_map { |hint| hinter.lookup(hint) }.first
    target.text.should eq("src/main.cr")
    output.contents.should contain(Fingers.config.hint_style + target.hint)
    output.contents.should contain(Fingers.config.highlight_style + "rc/main.cr")

    state.selected_hints << target.hint
    output.contents = ""
    hinter.run
    output.contents.should contain(Fingers.config.selected_hint_style + target.hint)
    output.contents.should contain(Fingers.config.selected_highlight_style + "rc/main.cr")
  end

  it "keeps right-positioned hints inside named captures in layout mode" do
    original_position = Fingers.config.hint_position
    Fingers.config.hint_position = "right"
    output = TextOutput.new
    hinter = Fingers::Hinter.new(
      input: ["prefix: src/main.cr suffix"], width: 80,
      patterns: ["prefix: (?<match>src/main\\.cr)"],
      state: ::Fingers::State.new, output: output, alphabet: ["a", "b"],
      preserve_layout: true,
    )
    hinter.run
    target = ["a", "b"].compact_map { |hint| hinter.lookup(hint) }.first
    output.contents.should contain(Fingers.config.highlight_style + "src/main.c")
    output.contents.should contain(Fingers.config.hint_style + target.hint)
  ensure
    Fingers.config.hint_position = original_position.not_nil!
  end

  it "works in a grid of lines" do
    width = 100
    input = generate_lines
    output = TextOutput.new

    patterns = Fingers::BUILTIN_PATTERNS.values.to_a
    alphabet = "asdf".split("")

    hinter = Fingers::Hinter.new(
      input: input.split("\n"),
      width: width,
      patterns: patterns,
      state: ::Fingers::State.new,
      alphabet: alphabet,
      output: output,
    )
  end

  it "only highlights captured groups" do
    width = 100
    input = "
On branch ruby-rewrite-more-like-crystal-rewrite-amirite
Your branch is up to date with 'origin/ruby-rewrite-more-like-crystal-rewrite-amirite'.

Changes to be committed:
  (use \"git restore --staged <file>...\" to unstage)
        modified:   spec/lib/fingers/match_formatter_spec.cr

Changes not staged for commit:
  (use \"git add <file>...\" to update what will be committed)
  (use \"git restore <file>...\" to discard changes in working directory)
        modified:   .gitignore
        modified:   spec/lib/fingers/hinter_spec.cr
        modified:   spec/spec_helper.cr
        modified:   src/fingers/cli.cr
        modified:   src/fingers/dirs.cr
        modified:   src/fingers/match_formatter.cr
    "
    output = TextOutput.new

    patterns = Fingers::BUILTIN_PATTERNS.values.to_a
    patterns << "On branch (?<capture>.*)"
    alphabet = "asdf".split("")

    hinter = Fingers::Hinter.new(
      input: input.split("\n"),
      width: width,
      patterns: patterns,
      state: ::Fingers::State.new,
      alphabet: alphabet,
      output: output,
    )
  end

  it "only reuses hints when allow duplicates is false" do
    width = 100
    output = TextOutput.new

    patterns = Fingers::BUILTIN_PATTERNS.values.to_a
    alphabet = "asdf".split("")

    input = "
          modified:   src/fingers/cli.cr
          modified:   src/fingers/cli.cr
          modified:   src/fingers/cli.cr
    "

    hinter = Fingers::Hinter.new(
      input: input.split("\n"),
      width: width,
      patterns: patterns,
      state: ::Fingers::State.new,
      alphabet: alphabet,
      output: output,
      reuse_hints: false
    )

    hinter.run
  end

  it "can rerender when not reusing hints" do
    width = 100
    output = TextOutput.new

    patterns = Fingers::BUILTIN_PATTERNS.values.to_a
    alphabet = "asdf".split("")

    input = "
          modified:   src/fingers/cli.cr
          modified:   src/fingers/cli.cr
          modified:   src/fingers/cli.cr
    "

    hinter = Fingers::Hinter.new(
      input: input.split("\n"),
      width: width,
      patterns: patterns,
      state: ::Fingers::State.new,
      alphabet: alphabet,
      output: output,
      reuse_hints: false
    )

    hinter.run
    hinter.run
  end
end
