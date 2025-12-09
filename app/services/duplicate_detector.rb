class DuplicateDetector
  SIMILARITY_THRESHOLD = 0.5

  STOP_WORDS = Set.new(%w[
    a an the is are was were be been being have has had do does did
    will would could should may might must shall can to of and in that
    it for on with as at by from or but not this which what when where
    who how all each every both few more most other some such no nor
    only own same so than too very just also now here there then once
  ]).freeze

  def self.similar?(claim, existing_claims)
    new.similar?(claim, existing_claims)
  end

  def similar?(claim, existing_claims)
    return false if existing_claims.empty?

    claim_words = extract_content_words(claim)
    return false if claim_words.empty?

    existing_claims.any? do |existing|
      existing_words = extract_content_words(existing)
      next false if existing_words.empty?

      similarity = calculate_similarity(claim_words, existing_words)
      similarity >= SIMILARITY_THRESHOLD
    end
  end

  private

  def extract_content_words(text)
    text
      .downcase
      .gsub(/[^\w\s]/, "")  # Remove punctuation
      .split
      .reject { |word| word.length <= 2 || STOP_WORDS.include?(word) }
      .to_set
  end

  def calculate_similarity(words1, words2)
    overlap = (words1 & words2).size
    min_size = [words1.size, words2.size].min

    return 0.0 if min_size.zero?
    overlap.to_f / min_size
  end
end
