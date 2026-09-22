type META = {
    string: {
        __concat: (string | number, string | number) -> string,
        __lt: (string, string) -> boolean,
        __le: (string, string) -> boolean,
        __len: (string) -> number
    },
    table: {
        __len: (table) -> number
    },
    number: {
        __concat: (string | number, string | number) -> string,
        __add: (number, number) -> number,
        __sub: (number, number) -> number,
        __mul: (number, number) -> number,
        __div: (number, number) -> number,
        __idiv: (number, number) -> number,
        __mod: (number, number) -> number,
        __pow: (number, number) -> number,
        __lt: (number, number) -> boolean,
        __le: (number, number) -> boolean,
        __unm: (number) -> number
    },
}
