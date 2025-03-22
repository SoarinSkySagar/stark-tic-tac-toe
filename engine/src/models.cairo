use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, Debug, PartialEq)]
#[dojo::model]
pub struct Matchmaker {
    #[key]
    pub server: u8,
    pub last_board: u32,
    pub last_board_ready: bool,
}

#[derive(Drop, Serde, Debug, PartialEq)]
#[dojo::model]
pub struct Board {
    #[key]
    pub match_id: u32,
    pub players: Array<ContractAddress>,
    pub empty: Array<Position>,
    pub winner: ContractAddress,
    pub active: bool,
    pub ready: bool,
}

#[derive(Drop, Serde, Debug, PartialEq)]
#[dojo::model]
pub struct Player {
    #[key]
    pub address: ContractAddress,
    pub match_id: u32,
    pub marks: Array<Position>,
    pub turn: bool,
}

#[derive(Copy, Drop, Serde, IntrospectPacked, Debug, PartialEq)]
pub struct Position {
    pub i: u8,
    pub j: u8,
}

