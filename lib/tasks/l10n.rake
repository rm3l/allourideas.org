namespace :l10n do

  # flattens the yaml hash into 1 dimensional hash
  def flatten(hash, namespace=nil)
    flattened = {}
    namespace = namespace + '.' if namespace
    hash.each do |key, value|
      if value.class == Hash
        flattened.merge!(flatten(value, "#{namespace}#{key}"))
      else
        flattened["#{namespace}#{key}"] = value
      end
    end
    return flattened
  end

  # given a nested hash and key as string, find the value
  # key can be indicate nesting by being dot separated
  def getValue(hash, key)
    key.to_s.split('.').inject(hash) { |h, k| h[k] unless h.nil? }
  end

  # set a value in the hash given a string as key much like getValue
  def setValue(hash, key, value)
    subkeys = key.split('.')
    lastkey = subkeys.pop
    subhash = subkeys.inject(hash) do |h, k|
      h[k] = {} if h[k].nil? 
      h[k]
    end
    subhash[lastkey] = value
  end

  desc "Determine diff of keys between two yml files.  Call by keys_diff[filename1, filename2]"
  task :keys_diff, :file1, :file2 do |t, args|
    file1 = YAML::load(File.open(args[:file1]))
    file2 = YAML::load(File.open(args[:file2]))

    # ignore language designation, so start with first.second
    file1_keys = flatten(file1.first.second).keys
    file2_keys = flatten(file2.first.second).keys
    puts "Keys in #{args[:file2]} that are missing in #{args[:file1]}:"
    puts (file2_keys - file1_keys).sort
    puts "\n\nKeys in #{args[:file1]} that are missing in #{args[:file2]}:"
    puts (file1_keys - file2_keys).sort

  end

  task :get_english_yaml, :file1, :file2, :en_file do |t, args|
    file1 = YAML::load(File.open(args[:file1]))
    file2 = YAML::load(File.open(args[:file2]))
    en    = YAML::load(File.open(args[:en_file])).first.second

    # ignore language designation, so start with first.second
    file1_keys = flatten(file1.first.second).keys
    file2_keys = flatten(file2.first.second).keys
    newHash = {}
    (file2_keys - file1_keys).each do |key|
      value = getValue(en, key)
      setValue(newHash, "#{file1.first.first}.#{key}", value)
    end
    puts newHash.to_yaml
  end

  desc "Convert a YAML file to CSV.  Second parameter is secondary language to include, defaults to English."
  task :yaml_to_csv, :language1, :language2 do |t, args|
    require 'fastercsv'
    args = {:language2 => 'en'}.merge(args)
    path = Rails.root + "config/locales/allourideas/"
    file1 = YAML::load(File.open(path + "#{args[:language1]}.yml"))
    file2 = YAML::load(File.open(path + "#{args[:language2]}.yml"))
    userfacing = YAML::load(File.open(path + "he.yml"))
    hash1 = flatten(file1.first.second)
    hash2 = flatten(file2.first.second)
    userfacing_hash = flatten(userfacing.first.second)

    csv_string = FasterCSV.generate do |csv|
      csv << ["key", args[:language2], args[:language1]]
      csv << ['Thank you for helping to internationalize allourideas.org.  This spreadsheet has three columns.  The first column is a "key".  This column is for our code and you should not worry about it or change it.   The second column is the English phrase that appears on the website.  The final column is where you should add the appropriate phrase in your language.

Some of the strings will include "special characters" like "\n"; you should just ignore these special characters and change the text around them. 

For example, the key

"X_votes_on_Y_ideas

has this representation in English

 %{1}%{votes_count}%{_1} votes on %{2}%{ideas_count}%{_2} ideas

If you were translating to French you would write something like:

%{1}%{votes_count}%{_1} voix sur les %{2}%{ideas_count}%{_2} idées

Thank you again for your help. This process can be confusing, so please do not hesitate to ask questions.
']
      (hash1.keys + (userfacing_hash.keys - hash1.keys)).sort.each do |key|
        csv << [key, hash2[key], hash1[key]]
      end
    end
    puts csv_string
  end
end