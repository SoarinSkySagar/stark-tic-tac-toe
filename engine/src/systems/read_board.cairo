use engine::models::{Position};

#[starknet::interface]
pub trait IReadBoard<T> {
    fn read_board(self: @T) -> (Array<Position>, Array<Array<Position>>);
}

#[dojo::contract]
pub mod read_board {
    use super::{IReadBoard, Position};
    use starknet::{get_caller_address};
    use engine::models::{Board, Player};

    use dojo::model::{ModelStorage};

    #[abi(embed_v0)]
    impl ActionsImpl of IReadBoard<ContractState> {
        fn read_board(self: @ContractState) -> (Array<Position>, Array<Array<Position>>) {
            let mut world = self.world_default();
            let player = get_caller_address();
            let player_info: Player = world.read_model(player);
            let board: Board = world.read_model(player_info.match_id);

            let board_empty = board.empty;
            let mut all_marks: Array<Array<Position>> = array![];
            for p in board.players {
                let info: Player = world.read_model(p);
                all_marks.append(info.marks);
            };
            (board_empty, all_marks)
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"engine")
        }
    }
}

