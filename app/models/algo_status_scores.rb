# == Schema Information
#
# Table name: algo_status_scores
#
#  id         :bigint(8)        not null, primary key
#  positive_sentiment_rev_chrono :integer
#  negative_sentiment_rev_chrono :integer

class AlgoStatusScores < ExtRecord
  self.table_name = 'algo_status_scores'

  def self.ranking_method()
    "neg"
  end
  
  def self.get_sentiment_rev_chron(limit)
    if self.ranking_method() == "pos"
      self.get_positive_sentiment_rev_chron(limit)
    else
      self.get_negative_sentiment_rev_chron(limit)
    end
  end

  def self.get_positive_sentiment_rev_chron(limit)
      AlgoStatusScores.where('positive_sentiment_rev_chron > 0').order(positive_sentiment_rev_chron: :desc).limit(limit)
  end

  def self.get_negative_sentiment_rev_chron(limit)
    AlgoStatusScores.where('negative_sentiment_rev_chron > 0').order(negative_sentiment_rev_chron: :desc).limit(limit)
  end
  
end
