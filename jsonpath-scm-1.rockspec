package = "jsonpath"
version = "scm-1"

source = {
    url = "git://github.com/olegrok/tarantool-jsonpath.git",
    branch = 'master',
}

description = {
    summary = "Introspection tool for Tarantool jsonpath",
    homepage = "https://github.com/olegrok/tarantool-jsonpath",
    license = "MIT",
}

dependencies = {
    'tarantool',
}

build = {
    type = "builtin",
    modules = {
        ["jsonpath"] = "jsonpath.lua",
    },
}
