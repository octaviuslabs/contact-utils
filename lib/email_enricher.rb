require 'clearbit'
require 'csv'
require 'colorize'
require 'firebase'

Clearbit.key = "your-clearbit-key"
Clearbit::Person.version = '2015-05-27'
firebase_endpoint = 'firebase-endpoint'

Contact = Struct.new(:email_address)

def read_emails file_path
  contacts = []
  File.open(file_path, "r") do |f|
    f.each_line do |line|
      email = line.gsub(/\r/,"")
      email = email.gsub(/\n/,"")
      contacts << Contact.new(email)
    end
  end
  return contacts
end


def serialize clearbit_data
  if clearbit_data.person.nil?
    output_data = [clearbit_data.key_email, "nodata", "nodata", "nodata", "nodata"]
  else
    person = clearbit_data.fetch(:person){Hash.new}
    employment = person.fetch(:employment){Hash.new}
    output_data = [
      clearbit_data.key_email,
      person.fetch(:location){"nodata"},
      person.fetch(:linkedin){Hash.new}.fetch(:handle){"nodata"},
      employment.fetch(:name){"nodata"},
      employment.fetch(:title){"nodata"}
    ]
  end
  return output_data
end

def print_csv serialized_data
  CSV.open("output.csv", "wb") do |csv|
    serialized_data.each do |data|
      csv << data
    end
  end
end

def get_contact contact
  begin
    return Clearbit::Enrichment.find(email: contact.email_address, stream: true)
  rescue
    print " ERROR".colorize(:red)
    return Clearbit::Mash.new nil
  end
end

def firebase
  @firebase ||= Firebase::Client.new(firebase_endpoint)
end

def persist! clearbit_response
  unless clearbit_response.person.nil? and clearbit_response.company.nil?
    key = Digest::MD5.hexdigest clearbit_response.key_email
    key = "contacts/#{key}"
    return firebase.update(key, clearbit_response.merge({updated: Time.now.to_i}))
  end
  return Hash.new
end

def execute!
  contacts = read_emails("emails.txt")
  enriched_contacts = []
  serialized_data = []
  print "Processing #{contacts.count} emails\n"
  contacts.each do |contact|
    print "Running Enrichment On #{contact.email_address}"
    clearbit_data = get_contact(contact)
    clearbit_data.key_email = contact.email_address
    persist!(clearbit_data)
    serialized_data << serialize(clearbit_data)
    enriched_contacts << clearbit_data
    print " DONE\n".colorize(:green)
  end
  print "Printing CSV"
  print_csv serialized_data
  print " DONE\n".colorize(:green)
  return serialized_data
end

execute!
