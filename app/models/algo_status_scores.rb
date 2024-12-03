# == Schema Information
#
# Table name: algo_status_scores
#
#  id         :bigint(8)        not null, primary key
#  positive_sentiment_rev_chrono :integer
#  negative_sentiment_rev_chrono :integer

class AlgoStatusScores < ExtRecord
    self.table_name = 'algo_status_scores'
    
    def self.get_positive_sentiment_rev_chrono(limit)
        AlgoStatusScores.where('positive_sentiment_rev_chron > 0').order(positive_sentiment_rev_chrono: :desc).limit(limit)
    end
    
end
  