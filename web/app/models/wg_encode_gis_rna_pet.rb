class WgEncodeGisRnaPet < ActiveRecord::Base
  cattr_accessor :display_columns
  default_scope { where('obj_status is null') }

  @@display_columns = ["bio_rep", "cell", "lab_version", "localization", "replicate", "rna_extract", "view", "fname"]

  self.inheritance_column = nil

end