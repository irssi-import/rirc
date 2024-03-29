#define parameters
PRESENCE = :presence
MYPRESENCE = :mypresence
NETWORK = :network
MSG = :msg
MSG_XHTML = :msg_xhtml
ADDRESS = :address
ERR = :err
TOPIC = :topic
TOPIC_SET_BY = :topic_set_by
TOPIC_TIMESTAMP = :topic_timestamp
INIT = :init
DEINIT = :deinit
OWN = :own
SOURCE_PRESENCE = :source_presence
ADD = :add
REMOVE = :remove
TYPE = :type
TIME = :time
CHANNEL = :channel
REASON = :reason
IRC_MODE = :irc_mode
DATA = :data
INITIAL_PRESENCES_ADDED = :initial_presences_added
IDLE_STARTED =  :idle_started
IP = :ip
ERROR = :error
PORT = :port
NO_AUTOREPLY = :no_autoreply
NAME = :name
STATUS = :status
MODE = :mode
PROTOCOL = :protocol
REAL_NAME = :real_name
EVENT = :event
CHARSET = :charset
HOST = :host
AUTOCONNECT = :autoconnect
ID = :id
JOINED = :joined
CONNECTED = :connected

#define my own parameters
EVENT_TYPE = :event_type
REPLY_STATUS = :reply_status

#define some status constants
INACTIVE = 0
NEWDATA = 1
NEWMSG = 2
HIGHLIGHT = 3
ACTIVE = 0

#define buffer positions
BUFFER_START = 0
BUFFER_END = 1

#define some event constants
EVENT_MESSAGE = 'message'
EVENT_USERMESSAGE = 'usermessage'
EVENT_JOIN = 'join'
EVENT_USERJOIN = 'userjoin'
EVENT_PART = 'part'
EVENT_USERPART = 'userpart'
EVENT_ERROR = 'error'
EVENT_NOTICE = 'notice'
EVENT_TOPIC = 'topic'
EVENT_MODECHANGE = 'modechange'
EVENT_NICKCHANGE = 'nickchange'
EVENT_USERNICKCHANGE = 'usernickchange'
#EVENT_CTCP = 'ctcp'

TAGMAP = {'color'=>'foreground', 'font-weight' => 'weight', 'font-style' => 'style', 'background-color' => 'background'}

#this is probably incomplete and buggy, but I don't care!
HYPERLINKREGEXP = %r{(?:\b|^)((((http|ftp|irc|https)://|)([\w\-]+\.)+[a-zA-Z]{2,4}|(\d{1,3}\.){3}(\d{1,3}))(\:[0-9]+|)([.\/]{1}[^\s\n\(\)\[\]\r\<\>]+|\b|$))}

SENSITIVE = Proc.new {|x, y| x[0].name <=> y[0].name}
SENSITIVE_NOHASH = Proc.new {|x, y| x[0].name.sub('#', '') <=> y[0].name.sub('#', '')}
INSENSITIVE = Proc.new {|x, y| x[0].name.downcase <=> y[0].name.downcase}
INSENSITIVE_NOHASH = Proc.new {|x, y| x[0].name.downcase.sub('#', '') <=> y[0].name.downcase.sub('#', '')}

HIERARCHICAL = 0
FLAT = 1
