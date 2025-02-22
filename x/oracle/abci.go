package oracle

import (
	"errors"

	sdk "github.com/cosmos/cosmos-sdk/types"
	"github.com/medibloc/panacea-core/v2/x/oracle/keeper"
	"github.com/medibloc/panacea-core/v2/x/oracle/types"
)

func BeginBlocker(ctx sdk.Context, keeper keeper.Keeper) {
	handleOracleUpgrade(ctx, keeper)
}

func handleOracleUpgrade(ctx sdk.Context, keeper keeper.Keeper) {
	upgradeInfo, err := keeper.GetOracleUpgradeInfo(ctx)
	if err != nil {
		if errors.Is(err, types.ErrOracleUpgradeInfoNotFound) {
			return
		} else {
			panic(err)
		}
	}

	if upgradeInfo.ShouldExecute(ctx) {
		if err := keeper.ApplyUpgrade(ctx, upgradeInfo); err != nil {
			panic(err)
		}
	}
}
