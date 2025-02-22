package types

// DefaultGenesis returns the default Capability genesis state
func DefaultGenesis() *GenesisState {
	return &GenesisState{
		NextDealNumber: uint64(1),
		Deals:          []Deal{},
		Consents:       []Consent{},
	}
}

// Validate performs basic genesis state validation returning an error upon any
// failure.
func (gs GenesisState) Validate() error {
	for _, deal := range gs.Deals {
		if err := deal.ValidateBasic(); err != nil {
			return err
		}
	}

	for _, consent := range gs.Consents {
		if err := consent.ValidateBasic(); err != nil {
			return err
		}
	}

	return nil
}
