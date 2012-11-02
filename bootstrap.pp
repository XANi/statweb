class statweb::agent {
    package { [
               libcommon-sense-perl,
               libzeromq-perl,
               libfile-slurp-perl,
               libyaml-libyaml-perl,
               liblog-dispatch-perl,
               libev-perl,
               libanyevent-perl,
               ]:
                   ensure => installed
    }
}

include statweb::agent