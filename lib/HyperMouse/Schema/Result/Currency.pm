use utf8;
package HyperMouse::Schema::Result::Currency;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

HyperMouse::Schema::Result::Currency

=cut

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use MooseX::MarkAsMethods autoclean => 1;
extends 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::I18nRelationships>

=item * L<DBIx::Class::InflateColumn::DateTime>

=item * L<DBIx::Class::EncodedColumn>

=back

=cut

__PACKAGE__->load_components(
  "I18nRelationships",
  "InflateColumn::DateTime",
  "EncodedColumn",
);

=head1 TABLE: C<currency>

=cut

__PACKAGE__->table("currency");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  extra: {unsigned => 1}
  is_auto_increment: 1
  is_nullable: 0

=head2 valid_since

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 valid_till

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 removed

  data_type: 'datetime'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 code

  data_type: 'varchar'
  is_nullable: 0
  size: 3

=head2 sign

  data_type: 'char'
  is_nullable: 0
  size: 1

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type => "integer",
    extra => { unsigned => 1 },
    is_auto_increment => 1,
    is_nullable => 0,
  },
  "valid_since",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "valid_till",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "removed",
  {
    data_type => "datetime",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "code",
  { data_type => "varchar", is_nullable => 0, size => 3 },
  "sign",
  { data_type => "char", is_nullable => 0, size => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 currency_i18ns

Type: has_many

Related object: L<HyperMouse::Schema::Result::CurrencyI18n>

=cut

__PACKAGE__->has_many(
  "currency_i18ns",
  "HyperMouse::Schema::Result::CurrencyI18n",
  { "foreign.currency_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 currency_rates

Type: has_many

Related object: L<HyperMouse::Schema::Result::CurrencyRate>

=cut

__PACKAGE__->has_many(
  "currency_rates",
  "HyperMouse::Schema::Result::CurrencyRate",
  { "foreign.currency_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 payments

Type: has_many

Related object: L<HyperMouse::Schema::Result::Payment>

=cut

__PACKAGE__->has_many(
  "payments",
  "HyperMouse::Schema::Result::Payment",
  { "foreign.currency_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07046 @ 2017-03-28 01:07:05
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:lD2BP44dfT69xhDvzHpeFQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
__PACKAGE__->meta->make_immutable;
1;